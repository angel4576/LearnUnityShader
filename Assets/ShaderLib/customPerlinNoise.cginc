#ifndef CUSTOMPERLINNOISE_INCLUDED
#define CUSTOMPERLINNOISE_INCLUDED

int perm[512]; 
// = {
//             151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36,
//             103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0,
//             26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56,
//             87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166,
//             77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55,
//             46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132,
//             187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109,
//             198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126,
//             255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183,
//             170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43,
//             172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112,
//             104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162,
//             241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106,
//             157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205,
//             93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180,
//             151
//         };

// 非线性插值函数 ease curve
float fade(float t)
{
    return t * t * t * (t * (t * 6 - 15) + 10);
}

float perlinNoise(float x, float y, float z)
{
    // 输入的整数部分 计算点落在哪个单位正方体中
    // 这里&0xff作用是让 X 值范围为0-255，注意我们的目的是求Hash，这个操作只是减小随机范围
    int xi = (int)floor(x) & 0xff;
    int yi = (int)floor(y) & 0xff;
    int zi = (int)floor(z) & 0xff;

    // 小数部分 确定了输入坐标在单元正方形里的空间位置
    x -= (int)floor(x);
    y -= (int)floor(y);
    z -= (int)floor(z);

    // 在后面的插值计算中使用
    float u = fade(x);
    float v = fade(y);
    float w = fade(z);

    // 这些都是取Hash操作，在三维中，我们临近整数点有8个，现在得到的类似8个伪随机向量
    int A = (perm[xi] + yi) & 0xff;
    int B = (perm[xi + 1] + yi) & 0xff;
    int AA = (perm[A] + zi) & 0xff;
    int BA = (perm[B] + zi) & 0xff;
    int AB = (perm[A + 1] + zi) & 0xff;
    int BB = (perm[B + 1] + zi) & 0xff;

    float x1, x2, y1, y2;

    return 0;
}


#endif