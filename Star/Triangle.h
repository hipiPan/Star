#pragma once
#include "TriangleMesh.h"
#include "BBox.h"
#include "Ray.h"
#include "Intersection.h"
#include <memory>
//���ڽ�ʹ��Point����Normal����glm::vec3,Ŀ����Ϊ�˸�����������
//ע��:����Triangle�ڶ��������ϵ��������ģ������ϵ,��������û��������ı任���Ժ���������ϵ���ص���
class Triangle
{
public:
	Triangle(std::shared_ptr<TriangleMesh> mesh, int triangleNumber, glm::mat4 objectToWorld);
	~Triangle();
	BBox objectBound();
	BBox worldBound();
	bool intersect(Ray& r, Intersection& in);
	bool intersectP(Ray& r);
	void getPositionData(glm::vec3& p0, glm::vec3& p1, glm::vec3& p2);
    void getNormalData(glm::vec3& n0, glm::vec3& n1, glm::vec3& n2);
    void getUVData(glm::vec2& t0, glm::vec2& t1, glm::vec2& t2);

private:
	std::shared_ptr<TriangleMesh> mMesh;
	int mVertexIndices[3];
	glm::vec3 mNormal;
	//��ģ�Ϳռ䵽����ռ������ռ䵽ģ�Ϳռ�
	glm::mat4 mObjectToWorld, mWorldToObject;
};
