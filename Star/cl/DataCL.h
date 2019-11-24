#pragma once
#include "CoreCL.h"

RAY_CL_NAMESPACE_BEGIN

struct Ray
{
	cl_float4 orig;
	cl_float4 dir;
};

struct Camera 
{
	cl_float4 orig, fwd;
	cl_float4 side, up;
	cl_int flags;
	cl_int pad[3];
};

struct HitData 
{
	cl_int mask, objIndex, primIndex;
	cl_float t, u, v;
	cl_float2 rayID;
};

struct Environment 
{
	cl_float4 envColAndClamp;
	cl_uint   envMap;
	cl_int    pad[3];
};

template <typename T>
class GPUMemPool
{
public:
	GPUMemPool();
	~GPUMemPool();
private:
	void reserve(size_t reqCap);
private:
	cl_context mContext;
	cl_command_queue mCommandQueue;
	cl_mem mMem;
	cl_mem_flags mFlags;
	size_t mSize;
	size_t mCapacity;
	size_t mMaxSize;
};

RAY_CL_NAMESPACE_END
