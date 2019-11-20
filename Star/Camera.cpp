#include "Camera.h"

void Camera::tick()
{
	glm::vec2 offset = Input::instance().getMousePosition() - mLastPos;
	mLastPos = Input::instance().getMousePosition();
	if (Input::instance().getMouseButton(MouseButton::MouseRight))
	{
		mYaw += offset.x * 0.1f;
		mPitch += -offset.y * 0.1f;
		updateVectors();
		mView = glm::lookAt(mPos, mPos + mFront, mUp);
		mViewInv = glm::inverse(mView);
	}
	if (Input::instance().getMouseScrollWheel() != 0)
	{
		float sw = Input::instance().getMouseScrollWheel();
		mPos += mFront * sw * 0.1f;
		mView = glm::lookAt(mPos, mPos + mFront, mUp);
		mViewInv = glm::inverse(mView);
	}
}

void Camera::updateVectors()
{
	glm::vec3 front;
	front.x = cos(glm::radians(mYaw)) * cos(glm::radians(mPitch));
	front.y = sin(glm::radians(mPitch));
	front.z = sin(glm::radians(mYaw)) * cos(glm::radians(mPitch));
	mFront = glm::normalize(front);
	mRight = glm::normalize(glm::cross(mFront, glm::vec3(0, 1, 0)));
	mUp = glm::normalize(glm::cross(mRight, mFront));
}

void Camera::reSize(int w, int h)
{
	mWidth = w;
	mHeight = h;
	mRatio = mWidth / float(mHeight);
	mProj = glm::perspective(glm::radians(mFOV), mRatio, mNearClip, mFarClip);
}

bool Camera::GenerateRay(float s, float t, Ray& r)
{
	glm::mat4 viewProjectionMatrix = mProj * mView;
	glm::vec3 nearPoint = unProject(glm::vec4(0, 0, mWidth, mHeight),glm::vec2(s, t), 0.0, viewProjectionMatrix);
	glm::vec3 farPoint = unProject(glm::vec4(0, 0, mWidth, mHeight), glm::vec2(s, t), 1.0, viewProjectionMatrix);
	glm::vec3 dir = farPoint - nearPoint;
	glm::normalize(dir);
	r.mOrig = mPos;
	r.mDir = dir;
	r.mMin = GMath::Epsilon;
	r.mMax = GMath::Infinity;
	return true;
}
