/*
 * Copyright (c) 2019-2020, NVIDIA CORPORATION.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the NVIDIA CORPORATION nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL NVIDIA CORPORATION BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "taco2DenoiseTransformKernel.h"
#include "taco2Utils.h"

namespace nvinfer1
{
namespace plugin
{

/******************************************************************************
 * CONSTANTS ******************************************************************
 *****************************************************************************/

namespace
{

constexpr const int BLOCK_SIZE = 256;
}

/******************************************************************************
 * KERNELS ********************************************************************
 *****************************************************************************/

__global__ void magnitudeAndPhaseKernel(
    const float* const inputDevice, const float* const noiseDevice, float* const outputDevice, const int length)
{
    const int yIdx = blockIdx.y * blockDim.y + threadIdx.y;
    const int xIdx = blockIdx.x * blockDim.x + threadIdx.x;
    const int imgOffset = length * (gridDim.y * blockDim.y);
    const int batchOffset = blockIdx.z * 2 * imgOffset;

    if (xIdx < length)
    {
        const int idx = yIdx * length + xIdx + batchOffset;
        const float real = inputDevice[idx];
        const float img = inputDevice[idx + imgOffset];

        float mag = sqrt(real * real + img * img);
        const float phase = atan2(img, real);

        // remove noise from magnitude
        mag -= noiseDevice[yIdx];
        if (mag < 0)
        {
            mag = 0.0f;
        }

        outputDevice[idx] = cos(phase) * mag;
        outputDevice[idx + imgOffset] = sin(phase) * mag;
    }
}

/******************************************************************************
 * PUBLIC STATIC METHODS ******************************************************
 *****************************************************************************/

void Taco2DenoiseTransformKernel::compute(const int batchSize, const float* const inputDevice,
    const float* const noiseDevice, float* const outputDevice, const int width, const int inputLength,
    cudaStream_t stream)
{
    const dim3 grid(taco2::Taco2Utils::roundUpBlocks(inputLength, BLOCK_SIZE), width, batchSize);
    const dim3 block(BLOCK_SIZE);

    magnitudeAndPhaseKernel<<<grid, block, 0, stream>>>(inputDevice, noiseDevice, outputDevice, inputLength);
}

} // namespace plugin
} // namespace nvinfer1
