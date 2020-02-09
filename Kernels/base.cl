#define MAX_RENDER_DIST 20000.0f
#define PI 3.14159265359f
#define TWO_PI 6.28318530718f
#define INV_PI 0.31830988618f
#define INV_TWO_PI 0.15915494309f
__constant float EPSILON = 0.00003f;
__constant int SAMPLES = 32;

#include "types.cl"
#include "tools.cl"

float intersectSphere(const Sphere* sphere, const Ray* ray)
{
	float3 rayToCenter = sphere->pos - ray->origin;
	float b = dot(rayToCenter, ray->dir);
	float c = dot(rayToCenter, rayToCenter) - sphere->radius*sphere->radius;
	float disc = b * b - c;

	if (disc < 0.0f) return 0.0f;
	else disc = sqrt(disc);

	if ((b - disc) > EPSILON) return b - disc;
	if ((b + disc) > EPSILON) return b + disc;
	
	return 0.0f;
}

bool occludedScene(Ray* ray, __global BVHNode* nodes, __global Triangle* tris)
{
	int todoOffset = 0;
    int nodeNum = 0;
	int todo[128];

	while (true) 
	{
		BVHNode node = nodes[nodeNum];
		if (intersectBBox(ray->origin, ray->dir, node.bboxMin, node.bboxMax))
		{
			if (node.numPrimitive > 0)
			{
				// leaf node
				for (int i = 0; i < node.numPrimitive; ++i)
				{
					int inx = node.primitiveOffset + i;
					if (occludedTriangle(ray, &tris[inx]))
					{
						return true;
					}
				}

				// miss
				if (todoOffset == 0)
					break;
				nodeNum = todo[--todoOffset];
			}
			else 
            {
					todo[todoOffset++] = node.secondChildOffset;
					nodeNum = nodeNum + 1;
			}
		}
		else
		{
			// miss
			if (todoOffset == 0)
				break;
			nodeNum = todo[--todoOffset];
		}
	}
	return false;
}

IntersectData intersectScene(Ray* ray, __global BVHNode* nodes, __global Triangle* tris)
{
	IntersectData isect;
    isect.hit = false;
    isect.ray = *ray;
    isect.t = MAX_RENDER_DIST;

	int todoOffset = 0;
    int nodeNum = 0;
	int todo[64];

	while (true)
	{
		BVHNode node = nodes[nodeNum];
		if (intersectBBox(ray->origin, ray->dir, node.bboxMin, node.bboxMax))
		{
			if (node.numPrimitive > 0)
			{
				// leaf node
				for (int i = 0; i < node.numPrimitive; ++i)
				{
					int inx = node.primitiveOffset + i;
					intersectTriangle(ray, &tris[inx], &isect);
				}

				// miss
				if (todoOffset == 0)
					break;
				nodeNum = todo[--todoOffset];
			}
			else 
            {
					todo[todoOffset++] = node.secondChildOffset;
					nodeNum = nodeNum + 1;
			}
		}
		else 
		{
			// miss
			if (todoOffset == 0)
				break;
			nodeNum = todo[--todoOffset];
		}
	}
	return isect;
}

Ray genCameraRay(const int x_coord, const int y_coord, const int width, const int height, __constant Camera* cam, unsigned int* seed0, unsigned int* seed1)
{
	// u v w
	float3 w = normalize(cam->front);
	float3 u = normalize(cross(cam->up, w));
    float3 v = cross(w, u);
	
	float aspect = (float)(width) / (float)(height);
	float theta = cam->params.x * PI / 180.0;
    float halfHeight = tan(theta/2);
    float halfWidth = aspect * halfHeight;
	float3 origin = cam->orig + cam->front;
	float3 lowerLeftCorner = origin - halfWidth*cam->params.w*u - halfHeight*cam->params.w*v - cam->params.w*w;
	float3 horizontal = 2*halfWidth*cam->params.w*u;
    float3 vertical = 2*halfHeight*cam->params.w*v;
	float lensRadius = cam->params.z/2.0;
	float3 rd = lensRadius * randomInUnitDisk(seed0, seed1);
	float3 offset = u * rd.x + rd.y;
	float3 pixelPos = lowerLeftCorner + (float)x_coord*horizontal + (float)y_coord*vertical;
	Ray ray;
	ray.origin = cam->orig + offset;
	ray.dir = normalize(pixelPos - ray.origin);
	
	return ray;
}

float3 sampleDiffuse(float3 wo, float3* wi, float* pdf, float3 normal, __global Material* material, unsigned int* seed0, unsigned int* seed1)
{
    *wi = sampleHemisphereCosine(normal, seed0, seed1);
    *pdf = dot(*wi, normal) * INV_PI;

    return material->baseColor * INV_PI;
}

float3 sampleBrdf(float3 wo, float3* wi, float* pdf, float3 normal, __global Material* material, unsigned int* seed0, unsigned int* seed1)
{
	return sampleDiffuse(wo, wi, pdf, normal, material, seed0, seed1);
}

float3 Render(Ray* camray, __global BVHNode* nodes, __global Triangle* tris, __global Material* materials, unsigned int* seed0, unsigned int* seed1)
{
	float3 radiance = 0.0f;
    float3 beta = 1.0f;

	Ray ray = *camray;
	for (int i = 0; i < 10; ++i)
    {
        IntersectData isect = intersectScene(&ray, nodes, tris);
		
        if (!isect.hit)
        {
			float3 unitDir = ray.dir;
        	float t = 0.5f*(unitDir.y + 1.0f);
        	return ((1.0f - t)*(float3)(1.0f, 1.0f, 1.0f) + t * (float3)(0.5f, 0.7f, 1.0f)) * 0.5f;
        }
		__global Material* material = &materials[isect.object->mat];

		float3 lightPos = (float3)(0.0f, 1.5f, 0.0f);
		float3 lightColor = (float3)(0.85f, 0.85f, 0.85f);
		float ambientStrength = 0.1;
		float3 ambient = ambientStrength * lightColor;
		float3 lightDir = normalize(lightPos - isect.pos);
		float diff = dot(isect.normal, lightDir);
		float3 diffuse = diff * lightColor;
				
		return (ambient + diffuse) * material->baseColor;


		radiance += beta * material->emission * 500.0f;
		float3 wi;
		float3 wo = -ray.dir;
		float pdf = 0.0f;
		float3 f = sampleBrdf(wo, &wi, &pdf, isect.normal, material, seed0, seed1);
		if (pdf <= 0.0f) break;

		float3 mul = f * dot(wi, isect.normal) / pdf;
		beta *= mul;
		ray.dir = wi;
		ray.origin = isect.pos + wi * 0.01f;
    }
    return max(radiance, 0.0f);
}

__kernel void renderKernel(const int width, const int height, __constant Camera* cam, __global BVHNode* nodes, __global Triangle* tris, __global Material* materials, unsigned int frameCount, __write_only image2d_t output)
{
	Sphere light;
	light.radius = 0.2f;
	light.pos = (float3)(0.0f, 1.3f, 0.0f);
	light.color = (float3)(0.0f, 0.0f, 0.0f);
	light.emission  = (float3)(9.0f, 8.0f, 7.0f);

	unsigned int coordX = get_global_id(0);
	unsigned int coordY = get_global_id(1);
	unsigned int seed0 = coordX + hashUInt32(frameCount);
	unsigned int seed1 = coordY + hashUInt32(frameCount);

	Ray ray = genCameraRay(coordX, coordY, width, height, cam, &seed0, &seed1);
	float3 finalcolor = 0.0f;
	
	finalcolor = Render(&ray, nodes, tris, materials, &seed0, &seed1);

	// float t = intersectSphere(&light, &ray);
	// IntersectData isect = intersectScene(&ray, nodes, tris);
	// if(isect.hit || t != 0.0f)
	// {
	// 	finalcolor = (float3)(1.0f, 1.0f, 1.0f);
	// }

	int2 coord=(int2)(coordX, coordY);
	float4 val = (float4)(finalcolor.x, finalcolor.y, finalcolor.z, 1.0);
    write_imagef(output, coord, val);
}