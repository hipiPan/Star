#pragma once
#include "TriangleMesh.h"
#include "BBox.h"
#include <memory>
//���ڽ�ʹ��Point����Normal����glm::vec3,Ŀ����Ϊ�˸�����������
class Triangle
{
public:
	Triangle(std::shared_ptr<TriangleMesh> mesh, int triangleNumber, glm::mat4 objectToWorld);
	~Triangle();
	BBox objectBound();
	BBox worldBound();
private:
	std::shared_ptr<TriangleMesh> mMesh;
	int mVertexIndices[3];
	glm::vec3 mNormal;
	//��ģ�Ϳռ䵽����ռ������ռ䵽ģ�Ϳռ�
	glm::mat4 mObjectToWorld, mWorldToObject;
};
