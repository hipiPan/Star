__constant float EPSILON = 0.00003f;
__constant float PI = 3.14159265359f;
__constant int SAMPLES = 32;

#include "types.cl"
#include "bvh.cl"

static float get_random(unsigned int *seed0, unsigned int *seed1) {

	/* hash the seeds using bitwise AND operations and bitshifts */
	*seed0 = 36969 * ((*seed0) & 65535) + ((*seed0) >> 16);
	*seed1 = 18000 * ((*seed1) & 65535) + ((*seed1) >> 16);

	unsigned int ires = ((*seed0) << 16) + (*seed1);

	/* use union struct to convert int to float */
	union {
		float f;
		unsigned int ui;
	} res;

	res.ui = (ires & 0x007fffff) | 0x40000000;  /* bitwise AND, bitwise OR */
	return (res.f - 2.0f) / 2.0f;
}

Ray createCamRay(const int x_coord, const int y_coord, const int width, const int height){

	float fx = (float)x_coord / (float)width;  /* convert int in range [0 - width] to float in range [0-1] */
	float fy = (float)y_coord / (float)height; /* convert int in range [0 - height] to float in range [0-1] */

	/* calculate aspect ratio */
	float aspect_ratio = (float)(width) / (float)(height);
	float fx2 = (fx - 0.5f) * aspect_ratio;
	float fy2 = fy - 0.5f;

	/* determine position of pixel on screen */
	float3 pixel_pos = (float3)(fx2, fy2, 0.0f);

	/* create camera ray*/
	Ray ray;
	ray.origin = (float3)(0.0f, 0.1f, 2.0f); /* fixed camera position */
	ray.dir = normalize(pixel_pos - ray.origin); /* vector from camera to pixel on screen */

	return ray;
}

/* (__global Sphere* sphere, const Ray* ray) */
float intersect_sphere(const Sphere* sphere, const Ray* ray) /* version using local copy of sphere */
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

bool intersect_scene(__constant Sphere* spheres, const Ray* ray, float* t, int* sphere_id, const int sphere_count)
{
	/* initialise t to a very large number,
	so t will be guaranteed to be smaller
	when a hit with the scene occurs */

	float inf = 1e20f;
	*t = inf;

	/* check if the ray intersects each sphere in the scene */
	for (int i = 0; i < sphere_count; i++)  {

		Sphere sphere = spheres[i]; /* create local copy of sphere */

		/* float hitdistance = intersect_sphere(&spheres[i], ray); */
		float hitdistance = intersect_sphere(&sphere, ray);
		/* keep track of the closest intersection and hitobject found so far */
		if (hitdistance != 0.0f && hitdistance < *t) {
			*t = hitdistance;
			*sphere_id = i;
		}
	}
	return *t < inf; /* true when ray interesects the scene */
}

float3 trace(__constant Sphere* spheres, const Ray* camray, const int sphere_count, const int* seed0, const int* seed1){

	Ray ray = *camray;

	float3 accum_color = (float3)(0.0f, 0.0f, 0.0f);
	float3 mask = (float3)(1.0f, 1.0f, 1.0f);

	for (int bounces = 0; bounces < 16; bounces++){

		float t;   /* distance to intersection */
		int hitsphere_id = 0; /* index of intersected sphere */

		/* if ray misses scene, return background colour */
		if (!intersect_scene(spheres, &ray, &t, &hitsphere_id, sphere_count))
			return accum_color += mask * (float3)(0.15f, 0.15f, 0.25f);

		/* else, we've got a hit! Fetch the closest hit sphere */
		Sphere hitsphere = spheres[hitsphere_id]; /* version with local copy of sphere */

		/* compute the hitpoint using the ray equation */
		float3 hitpoint = ray.origin + ray.dir * t;

		/* compute the surface normal and flip it if necessary to face the incoming ray */
		float3 normal = normalize(hitpoint - hitsphere.pos);
		float3 normal_facing = dot(normal, ray.dir) < 0.0f ? normal : normal * (-1.0f);

		/* compute two random numbers to pick a random point on the hemisphere above the hitpoint*/
		float rand1 = 2.0f * PI * get_random(seed0, seed1);
		float rand2 = get_random(seed0, seed1);
		float rand2s = sqrt(rand2);

		float3 w = normal_facing;
		float3 axis = fabs(w.x) > 0.1f ? (float3)(0.0f, 1.0f, 0.0f) : (float3)(1.0f, 0.0f, 0.0f);
		float3 u = normalize(cross(axis, w));
		float3 v = cross(w, u);

		float3 newdir = normalize(u * cos(rand1)*rand2s + v*sin(rand1)*rand2s + w*sqrt(1.0f - rand2));

		ray.origin = hitpoint + normal_facing * EPSILON;
		ray.dir = newdir;

		accum_color += mask * hitsphere.emission;

		mask *= hitsphere.color;

		mask *= dot(newdir, normal_facing);
	}

	return accum_color;
}	

Ray genCameraRay(const int x_coord, const int y_coord, const int width, const int height, __constant Camera* cam) 
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
	float3 pixelPos = lowerLeftCorner + (float)x_coord*horizontal + (float)y_coord*vertical;
	Ray ray;
	ray.origin = cam->orig; 
	ray.dir = normalize(pixelPos - ray.origin);
	
	// float fx = (float)x_coord / (float)width;
	// float fy = (float)y_coord / (float)height;

	// /* calculate aspect ratio */
	// float aspect_ratio = (float)(width) / (float)(height);
	// float fx2 = (fx - 0.5f) * aspect_ratio;
	// float fy2 = fy - 0.5f;

	// /* determine position of pixel on screen */
	// float3 pixel_pos = (float3)(fx2, fy2, 0.0f);

	// Ray ray;
	// ray.origin = (float3)(0.0f, 0.1f, 2.0f); 
	// ray.dir = normalize(pixel_pos - ray.origin);

	return ray;
}

__kernel void render_kernel(__constant Sphere* spheres, const int width, const int height, const int sphere_count, 
							__write_only image2d_t output, const int hashedframenumber, __constant Camera* cam, __constant BVHNode* nodes)
{
	unsigned int x_coord = get_global_id(0);
	unsigned int y_coord = get_global_id(1);

	unsigned int seed0 = x_coord + hashedframenumber;
	unsigned int seed1 = y_coord + hashedframenumber;

	Ray camray = genCameraRay(x_coord, y_coord, width, height, cam);
	float3 finalcolor = (float3)(0.0f, 0.0f, 0.0f);
	if(intersectBVH(&camray, nodes))
	{
		finalcolor = (float3)(1.0f, 1.0f, 1.0f);
	}
	int2 coord=(int2)(get_global_id(0), get_global_id(1));
	float4 val = (float4)(finalcolor.x, finalcolor.y, finalcolor.z, 1.0);
    write_imagef(output, coord, val);
/*
	float3 finalcolor = (float3)(0.0f, 0.0f, 0.0f);
	float invSamples = 1.0f / SAMPLES;

	for (int i = 0; i < SAMPLES; i++)
		finalcolor += trace(spheres, &camray, sphere_count, &seed0, &seed1) * invSamples;

	finalcolor = (float3)(clamp(finalcolor.x, 0.0f, 1.0f), 
		clamp(finalcolor.y, 0.0f, 1.0f), clamp(finalcolor.z, 0.0f, 1.0f));


	int2 coord=(int2)(get_global_id(0), get_global_id(1));
    uint4 value=255;
	float4 val = (float4)(finalcolor.x, finalcolor.y, finalcolor.z, 1.0);
    write_imagef(output, coord, val);
*/
}