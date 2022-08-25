// Very simple (and slow) implementation of point pillars
// to be converted into HLSL

#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <stdio.h>
#include <vector>
#include <thread>
#include <algorithm>
#include <numeric>

class pillar
{
private:
    const int max_voxels = 20000;
    const int max_points = 32; // max points per voxel grid
    const int num_features = 4;
    const float coors_range[6] = { 0.0f, -39.68f, -3.0f, 69.12f, 39.68f, 1.0f };
    const float voxel_size[3] = { 0.16f, 0.16f, 4.0f };
    const float anchor_ranges[18] =
    {
        0.0f, -39.68f, -0.6f,  69.12f, 39.68f, -0.6f,
        0.0f, -39.68f, -0.6f,  69.12f, 39.68f, -0.6f,
        0.0f, -39.68f, -1.78f, 69.12f, 39.68f, -1.78f
    };
    const float anchor_size[9] =
    {
        0.6f, 0.8f,  1.73f,
        0.6f, 1.76f, 1.73f,
        1.6f, 3.9f,  1.56f
    };
    const float anchor_rotations[2] = { 0.0f, 1.57f };

    // weights
    float** const0;

    float**** const3, **** const6, **** const9, **** const12, **** const15, **** const18,
        **** const21, **** const24, **** const27, **** const30, **** const33, **** const36,
        **** const39, **** const42, **** const45, **** const48, **** const51, **** const54,
        **** const57, **** const60, **** const62, **** const64;

    // bias, batch regularization values
    float* const1, * const2, * const4, * const5, * const7, * const8, * const10, * const11,
        * const13, * const14, * const16, * const17, * const19, * const20, * const22,
        * const23, * const25, * const26, * const28, * const29, * const31, * const32,
        * const34, * const35, * const37, * const38, * const40, * const41, * const43,
        * const44, * const46, * const47, * const49, * const50, * const52, * const53,
        * const55, * const56, * const58, * const59, * const61, * const63, * const65;

    // running mean + variance for batch regularization
    float* rm0, * rv0, * rm1, * rv1, * rm2, * rv2, * rm3, * rv3, * rm4, * rv4,
        * rm5, * rv5, * rm6, * rv6, * rm7, * rv7, * rm8, * rv8, * rm9, * rv9,
        * rm10, * rv10, * rm11, * rv11, * rm12, * rv12, * rm13, * rv13, * rm14, * rv14,
        * rm15, * rv15, * rm16, * rv16, * rm17, * rv17, * rm18, * rv18, * rm19, * rv19;

    // output layers
    std::vector<float*> input;

    float*** l1, *** l3, ** l4, ** l5, *** l6, ** l7, *** l8, *** l9, *** l10, *** l11,
        *** l12, *** l13, *** l14, *** l15, *** l16, *** l17, *** l18, *** l19, *** l20,
        *** l21, *** l22, *** l23, *** l24, *** l25, *** l26, *** l27, *** l28, *** l29,
        *** l30, *** l31, *** l32, *** l33, ** l36, ** l37, ** l39, ** l40, ** l41;
    int** l0, * l2, * l38;

    // sorting is easier :rolling_eyes:
    std::vector<float> l34;
    std::vector<int> l35;

    // final output
    std::vector<float*> ret_bboxes;
    std::vector<int> ret_labels;
    std::vector<float> ret_scores;

    inline float relu(float x)
    {
        return x < 0.0f ? 0.0f : x;
    }

    inline float sigmoid(float x)
    {
        return 1.0f / (1.0f + expf(-x));
    }

    inline float batchNorm(float x, float gamma, float beta, float mean, float var)
    {
        // z = (x - pop_mean) / sqrt(pop_var + epsilon)
        // bn = gamma * z + beta
        return ((x - mean) / sqrtf(var + 0.001f)) * gamma + beta;
    }

    inline float padLayerUneven(float*** layer, int x, int y, int z)
    {
        if (y == 0 || z == 0) return 0.0f;
        return layer[x][y - 1][z - 1];
    }

    inline float padLayerEven(float*** layer, int x, int y, int z, int ym, int zm)
    {
        if (y == 0 || z == 0 || y > ym || z > zm) return 0.0f;
        return layer[x][y - 1][z - 1];
    }

    inline float getAnchorRange(int x, int y)
    {
        return anchor_ranges[6 * x + y];
    }

    inline float getAnchorSize(int x, int y)
    {
        return anchor_size[3 * x + y];
    }

    // mapping 2d -> 3d array
    float reshape2to3(float*** cl, int width, int x, int y)
    {
        int i = y + (x * width) % (width * 6);
        int j = x / 1296;
        int k = (x / 6) % 216;
        return cl[i][j][k];
    }

    // mapping anchor 2d -> 3d array
    float anchor2to3(int x, int y)
    {
        float*** anchorArray[3] = { l31, l32, l33 };
        int i = x / 1296;
        int j = (x / 6) % 216;
        int k = (x % 2) + y * 2;
        return anchorArray[(x / 2) % 3][i][j][k];
    }

    float limit_period(float val, float offset, float period)
    {
        return val - floorf(val / period + offset) * period;
    }

    float**** getArray(std::ifstream* fin, int mi, int mj, int mk, int ml)
    {
        float**** buff = createArray(mi, mj, mk, ml);
        for (int i = 0; i < mi; i++) {
            for (int j = 0; j < mj; j++) {
                for (int k = 0; k < mk; k++) {
                    fin->read(reinterpret_cast<char*>(buff[i][j][k]), sizeof(float) * ml);
                }
            }
        }
        return buff;
    }

    float*** getArray(std::ifstream* fin, int mi, int mj, int mk)
    {
        float*** buff = createArray(mi, mj, mk);
        for (int i = 0; i < mi; i++) {
            for (int j = 0; j < mj; j++) {
                fin->read(reinterpret_cast<char*>(buff[i][j]), sizeof(float) * mk);
            }
        }
        return buff;
    }

    float** getArray(std::ifstream* fin, int mi, int mj)
    {
        float** buff = createArray(mi, mj);
        for (int i = 0; i < mi; i++) {
            fin->read(reinterpret_cast<char*>(buff[i]), sizeof(float) * mj);
        }
        return buff;
    }

    float* getArray(std::ifstream* fin, int mi)
    {
        float* buff = (float*)malloc(mi * sizeof(float));
        fin->read(reinterpret_cast<char*>(buff), sizeof(float) * mi);
        return buff;
    }

public:

    template <typename T, typename Compare>
    std::vector<std::size_t> sort_permutation(
        const std::vector<T>& vec,
        Compare compare)
    {
        std::vector<std::size_t> p(vec.size());
        std::iota(p.begin(), p.end(), 0);
        std::sort(p.begin(), p.end(),
            [&](std::size_t i, std::size_t j) { return compare(vec[i], vec[j]); });
        return p;
    }

    template <typename T>
    void apply_permutation_in_place(
        std::vector<T>& vec,
        const std::vector<std::size_t>& p)
    {
        std::vector<bool> done(vec.size());
        for (std::size_t i = 0; i < vec.size(); ++i)
        {
            if (done[i])
            {
                continue;
            }
            done[i] = true;
            std::size_t prev_j = i;
            std::size_t j = p[i];
            while (i != j)
            {
                std::swap(vec[prev_j], vec[j]);
                done[j] = true;
                prev_j = j;
                j = p[j];
            }
        }
    }

    // Annoying mallocs

    static int** createArrayInt(int i, int j)
    {
        int** r = new int* [i];
        for (int x = 0; x < i; x++) {
            r[x] = new int[j];
            memset(r[x], 0, j * sizeof(int));
        }
        return r;
    }

    static int*** createArrayInt(int i, int j, int k)
    {
        int*** r = new int** [i];
        for (int x = 0; x < i; x++) {
            r[x] = new int* [j];
            for (int y = 0; y < j; y++) {
                r[x][y] = new int[k];
                memset(r[x][y], 0, k * sizeof(int));
            }
        }
        return r;
    }

    static float** createArray(int i, int j)
    {
        float** r = new float* [i];
        for (int x = 0; x < i; x++) {
            r[x] = new float[j];
            memset(r[x], 0, j * sizeof(float));
        }
        return r;
    }

    static float*** createArray(int i, int j, int k)
    {
        float*** r = new float** [i];
        for (int x = 0; x < i; x++) {
            r[x] = new float* [j];
            for (int y = 0; y < j; y++) {
                r[x][y] = new float[k];
                memset(r[x][y], 0, k * sizeof(float));
            }
        }
        return r;
    }

    static float**** createArray(int i, int j, int k, int l)
    {
        float**** r = new float*** [i];
        for (int x = 0; x < i; x++) {
            r[x] = new float** [j];
            for (int y = 0; y < j; y++) {
                r[x][y] = new float* [k];
                for (int z = 0; z < k; z++) {
                    r[x][y][z] = new float[l];
                    memset(r[x][y][z], 0, l * sizeof(float));
                }
            }
        }
        return r;
    }

    // Annoying malloc frees
    static void freeArray(int i, float* a)
    {
        delete[] a;
    }

    static void freeArray(int i, int j, float** a)
    {
        for (int x = 0; x < i; x++) {
            delete[] a[x];
        }
        delete[] a;
    }

    static void freeArray(int i, int j, int k, float*** a)
    {
        for (int x = 0; x < i; x++) {
            for (int y = 0; y < j; y++) {
                delete[] a[x][y];
            }
            delete[] a[x];
        }
        delete[] a;
    }

    static void freeArray(int i, int j, int k, int l, float**** a)
    {
        for (int x = 0; x < i; x++) {
            for (int y = 0; y < j; y++) {
                for (int z = 0; z < k; z++) {
                    delete[] a[x][y][z];
                }
                delete[] a[x][y];
            }
            delete[] a[x];
        }
        delete[] a;
    }

    pillar(std::string pathWeights, std::string pathMeanVar, std::string pathInput)
    {
        std::ifstream fin(pathWeights, std::ios::binary);
        if (!fin) {
            std::cout << "error opening weights file" << std::endl;
            exit(-1);
        }

        const0 = getArray(&fin, 64, 9);
        const1 = getArray(&fin, 64);
        const2 = getArray(&fin, 64);
        const3 = getArray(&fin, 64, 64, 3, 3);
        const4 = getArray(&fin, 64);
        const5 = getArray(&fin, 64);
        const6 = getArray(&fin, 64, 64, 3, 3);
        const7 = getArray(&fin, 64);
        const8 = getArray(&fin, 64);
        const9 = getArray(&fin, 64, 64, 3, 3);
        const10 = getArray(&fin, 64);
        const11 = getArray(&fin, 64);
        const12 = getArray(&fin, 64, 64, 3, 3);
        const13 = getArray(&fin, 64);
        const14 = getArray(&fin, 64);
        const15 = getArray(&fin, 128, 64, 3, 3);
        const16 = getArray(&fin, 128);
        const17 = getArray(&fin, 128);
        const18 = getArray(&fin, 128, 128, 3, 3);
        const19 = getArray(&fin, 128);
        const20 = getArray(&fin, 128);
        const21 = getArray(&fin, 128, 128, 3, 3);
        const22 = getArray(&fin, 128);
        const23 = getArray(&fin, 128);
        const24 = getArray(&fin, 128, 128, 3, 3);
        const25 = getArray(&fin, 128);
        const26 = getArray(&fin, 128);
        const27 = getArray(&fin, 128, 128, 3, 3);
        const28 = getArray(&fin, 128);
        const29 = getArray(&fin, 128);
        const30 = getArray(&fin, 128, 128, 3, 3);
        const31 = getArray(&fin, 128);
        const32 = getArray(&fin, 128);
        const33 = getArray(&fin, 256, 128, 3, 3);
        const34 = getArray(&fin, 256);
        const35 = getArray(&fin, 256);
        const36 = getArray(&fin, 256, 256, 3, 3);
        const37 = getArray(&fin, 256);
        const38 = getArray(&fin, 256);
        const39 = getArray(&fin, 256, 256, 3, 3);
        const40 = getArray(&fin, 256);
        const41 = getArray(&fin, 256);
        const42 = getArray(&fin, 256, 256, 3, 3);
        const43 = getArray(&fin, 256);
        const44 = getArray(&fin, 256);
        const45 = getArray(&fin, 256, 256, 3, 3);
        const46 = getArray(&fin, 256);
        const47 = getArray(&fin, 256);
        const48 = getArray(&fin, 256, 256, 3, 3);
        const49 = getArray(&fin, 256);
        const50 = getArray(&fin, 256);
        const51 = getArray(&fin, 64, 128, 1, 1);
        const52 = getArray(&fin, 128);
        const53 = getArray(&fin, 128);
        const54 = getArray(&fin, 128, 128, 2, 2);
        const55 = getArray(&fin, 128);
        const56 = getArray(&fin, 128);
        const57 = getArray(&fin, 256, 128, 4, 4);
        const58 = getArray(&fin, 128);
        const59 = getArray(&fin, 128);
        const60 = getArray(&fin, 18, 384, 1, 1);
        const61 = getArray(&fin, 18);
        const62 = getArray(&fin, 42, 384, 1, 1);
        const63 = getArray(&fin, 42);
        const64 = getArray(&fin, 12, 384, 1, 1);
        const65 = getArray(&fin, 12);

        fin.close();

        // pytorch doesn't save running mean/variance of the training set automatically
        // here I am loading it seperately

        std::ifstream fin3(pathMeanVar, std::ios::binary);
        if (!fin3) {
            std::cout << "error opening mean/variance file" << std::endl;
            exit(-1);
        }

        // 0 <class 'torch.nn.modules.batchnorm.BatchNorm1d'>
        rm0 = getArray(&fin3, 64);
        rv0 = getArray(&fin3, 64);
        // 1 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm1 = getArray(&fin3, 64);
        rv1 = getArray(&fin3, 64);
        // 2 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm2 = getArray(&fin3, 64);
        rv2 = getArray(&fin3, 64);
        // 3 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm3 = getArray(&fin3, 64);
        rv3 = getArray(&fin3, 64);
        // 4 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm4 = getArray(&fin3, 64);
        rv4 = getArray(&fin3, 64);
        // 5 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm5 = getArray(&fin3, 128);
        rv5 = getArray(&fin3, 128);
        // 6 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm6 = getArray(&fin3, 128);
        rv6 = getArray(&fin3, 128);
        // 7 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm7 = getArray(&fin3, 128);
        rv7 = getArray(&fin3, 128);
        // 8 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm8 = getArray(&fin3, 128);
        rv8 = getArray(&fin3, 128);
        // 9 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm9 = getArray(&fin3, 128);
        rv9 = getArray(&fin3, 128);
        // 10 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm10 = getArray(&fin3, 128);
        rv10 = getArray(&fin3, 128);
        // 11 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm11 = getArray(&fin3, 256);
        rv11 = getArray(&fin3, 256);
        // 12 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm12 = getArray(&fin3, 256);
        rv12 = getArray(&fin3, 256);
        // 13 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm13 = getArray(&fin3, 256);
        rv13 = getArray(&fin3, 256);
        // 14 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm14 = getArray(&fin3, 256);
        rv14 = getArray(&fin3, 256);
        // 15 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm15 = getArray(&fin3, 256);
        rv15 = getArray(&fin3, 256);
        // 16 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm16 = getArray(&fin3, 256);
        rv16 = getArray(&fin3, 256);
        // 17 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm17 = getArray(&fin3, 128);
        rv17 = getArray(&fin3, 128);
        // 18 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm18 = getArray(&fin3, 128);
        rv18 = getArray(&fin3, 128);
        // 19 <class 'torch.nn.modules.batchnorm.BatchNorm2d'>
        rm19 = getArray(&fin3, 128);
        rv19 = getArray(&fin3, 128);

        fin3.close();

        //// layers
        l0 = createArrayInt(max_voxels, 3);      // coords
        l1 = createArray(max_voxels, 32, 4);     // pillars
        l2 = new int[max_voxels];                // pillar points count
        for (int i = 0; i < max_voxels; i++) l2[i] = 0;
        l3 = createArray(max_voxels, 32, 3);     // center point offsets
        l4 = createArray(max_voxels, 32);        // center pillar x offsets
        l5 = createArray(max_voxels, 32);        // center pillar y offsets
        l6 = createArray(max_voxels, 32, 64);    // concat features, convolve, batch norm, relu
        l7 = createArray(max_voxels, 64);        // max pool
        // single shot detector architecture used in object detection
        // backbone
        l8 = createArray(64, 496, 432);          // pillar scatter
        l9 = createArray(64, 248, 216);          // conv + batch norm + relu
        l10 = createArray(64, 248, 216);         // conv + batch norm + relu
        l11 = createArray(64, 248, 216);         // conv + batch norm + relu
        l12 = createArray(64, 248, 216);         // conv + batch norm + relu
        l13 = createArray(128, 124, 108);        // conv + batch norm + relu
        l14 = createArray(128, 124, 108);        // conv + batch norm + relu
        l15 = createArray(128, 124, 108);        // conv + batch norm + relu
        l16 = createArray(128, 124, 108);        // conv + batch norm + relu
        l17 = createArray(128, 124, 108);        // conv + batch norm + relu
        l18 = createArray(128, 124, 108);        // conv + batch norm + relu
        l19 = createArray(256, 62, 54);          // conv + batch norm + relu
        l20 = createArray(256, 62, 54);          // conv + batch norm + relu
        l21 = createArray(256, 62, 54);          // conv + batch norm + relu
        l22 = createArray(256, 62, 54);          // conv + batch norm + relu
        l23 = createArray(256, 62, 54);          // conv + batch norm + relu
        l24 = createArray(256, 62, 54);          // conv + batch norm + relu
        // neck
        l25 = createArray(128, 248, 216);        // conv transpose + batch norm + relu
        l26 = createArray(128, 248, 216);        // conv transpose + batch norm + relu
        l27 = createArray(128, 248, 216);        // conv transpose + batch norm + relu
        // head
        l28 = createArray(18, 248, 216);         // conv
        l29 = createArray(42, 248, 216);         // conv
        l30 = createArray(12, 248, 216);         // conv
        // anchor calcs
        l31 = createArray(248, 216, 14);
        l32 = createArray(248, 216, 14);
        l33 = createArray(248, 216, 14);
        // top 100
        l36 = createArray(100, 3);
        l37 = createArray(100, 7);
        l38 = new int[100];
        l39 = createArray(100, 7);
        l40 = createArray(100, 7);
        l41 = createArray(100, 5);

        // get input
        std::ifstream fin2(pathInput, std::ios::binary);
        if (!fin2) {
            std::cout << "error opening input file" << std::endl;
            exit(-1);
        }

        fin2.seekg(0, std::ios::end);
        const size_t num_elements = fin2.tellg() / sizeof(float) / 4;
        fin2.seekg(0, std::ios::beg);

        for (size_t i = 0; i < num_elements; i++)
        {
            float* entry = getArray(&fin2, 4);
            input.push_back(entry);
        }

        fin2.close();
    }

    ~pillar()
    {
        // weights
        freeArray(64, 9, const0);
        freeArray(64, const1);
        freeArray(64, const2);
        freeArray(64, 64, 3, 3, const3);
        freeArray(64, const4);
        freeArray(64, const5);
        freeArray(64, 64, 3, 3, const6);
        freeArray(64, const7);
        freeArray(64, const8);
        freeArray(64, 64, 3, 3, const9);
        freeArray(64, const10);
        freeArray(64, const11);
        freeArray(64, 64, 3, 3, const12);
        freeArray(64, const13);
        freeArray(64, const14);
        freeArray(128, 64, 3, 3, const15);
        freeArray(128, const16);
        freeArray(128, const17);
        freeArray(128, 128, 3, 3, const18);
        freeArray(128, const19);
        freeArray(128, const20);
        freeArray(128, 128, 3, 3, const21);
        freeArray(128, const22);
        freeArray(128, const23);
        freeArray(128, 128, 3, 3, const24);
        freeArray(128, const25);
        freeArray(128, const26);
        freeArray(128, 128, 3, 3, const27);
        freeArray(128, const28);
        freeArray(128, const29);
        freeArray(128, 128, 3, 3, const30);
        freeArray(128, const31);
        freeArray(128, const32);
        freeArray(256, 128, 3, 3, const33);
        freeArray(256, const34);
        freeArray(256, const35);
        freeArray(256, 256, 3, 3, const36);
        freeArray(256, const37);
        freeArray(256, const38);
        freeArray(256, 256, 3, 3, const39);
        freeArray(256, const40);
        freeArray(256, const41);
        freeArray(256, 256, 3, 3, const42);
        freeArray(256, const43);
        freeArray(256, const44);
        freeArray(256, 256, 3, 3, const45);
        freeArray(256, const46);
        freeArray(256, const47);
        freeArray(256, 256, 3, 3, const48);
        freeArray(256, const49);
        freeArray(256, const50);
        freeArray(64, 128, 1, 1, const51);
        freeArray(128, const52);
        freeArray(128, const53);
        freeArray(128, 128, 2, 2, const54);
        freeArray(128, const55);
        freeArray(128, const56);
        freeArray(256, 128, 4, 4, const57);
        freeArray(128, const58);
        freeArray(128, const59);
        freeArray(18, 384, 1, 1, const60);
        freeArray(18, const61);
        freeArray(42, 384, 1, 1, const62);
        freeArray(42, const63);
        freeArray(12, 384, 1, 1, const64);
        freeArray(12, const65);

        freeArray(64, rm0);
        freeArray(64, rv0);
        freeArray(64, rm1);
        freeArray(64, rv1);
        freeArray(64, rm2);
        freeArray(64, rv2);
        freeArray(64, rm3);
        freeArray(64, rv3);
        freeArray(64, rm4);
        freeArray(64, rv4);
        freeArray(128, rm5);
        freeArray(128, rv5);
        freeArray(128, rm6);
        freeArray(128, rv6);
        freeArray(128, rm7);
        freeArray(128, rv7);
        freeArray(128, rm8);
        freeArray(128, rv8);
        freeArray(128, rm9);
        freeArray(128, rv9);
        freeArray(128, rm10);
        freeArray(128, rv10);
        freeArray(256, rm11);
        freeArray(256, rv11);
        freeArray(256, rm12);
        freeArray(256, rv12);
        freeArray(256, rm13);
        freeArray(256, rv13);
        freeArray(256, rm14);
        freeArray(256, rv14);
        freeArray(256, rm15);
        freeArray(256, rv15);
        freeArray(256, rm16);
        freeArray(256, rv16);
        freeArray(128, rm17);
        freeArray(128, rv17);
        freeArray(128, rm18);
        freeArray(128, rv18);
        freeArray(128, rm19);
        freeArray(128, rv19);

        // outputs

    }

    std::vector<float*> point_range_filter(std::vector<float*> input)
    {
        // point_range: [x1, y1, z1, x2, y2, z2]
        std::vector<float*> filteredIn;
        for (int i = 0; i < input.size(); i++)
        {
            bool skip = false;
            float* entry = input.at(i);
            if (entry[0] <= coors_range[0] || entry[0] >= coors_range[3]) skip = true;
            if (entry[1] <= coors_range[1] || entry[1] >= coors_range[4]) skip = true;
            if (entry[2] <= coors_range[2] || entry[2] >= coors_range[5]) skip = true;
            if (!skip) filteredIn.push_back(entry);
            else delete[] entry;
        }

        return filteredIn;
    }

    /*
        Copied from point pillar's voxelization_cpu.cpp
    */

    int hard_voxelize_cpu(
        std::vector<float*> points,
        int** coors,
        float*** voxels,
        int* num_points_per_voxel)
    {
        const int NDim = 3;
        const int ndim_minus_1 = NDim - 1;
        bool failed = false;
        int* coor = new int[NDim]();
        int c;

        int** temp_coors = createArrayInt(points.size(), NDim);

        std::vector<int> grid_size(NDim);
        for (int i = 0; i < NDim; ++i) {
            grid_size[i] =
                roundf((coors_range[NDim + i] - coors_range[i]) / voxel_size[i]);
        }

        // change the floating point values of the input into 0 to ~500 on a grid of
        // type int and flip xyz into zyx
        for (int i = 0; i < points.size(); ++i) {
            failed = false;
            for (int j = 0; j < NDim; ++j) {
                c = (int) floorf((points[i][j] - coors_range[j]) / voxel_size[j]);
                // necessary to rm points out of range
                if ((c < 0 || c >= grid_size[j])) {
                    failed = true;
                    break;
                }
                coor[ndim_minus_1 - j] = c;
            }

            for (int k = 0; k < NDim; ++k) {
                if (failed)
                    temp_coors[i][k] = -1;
                else
                    temp_coors[i][k] = coor[k];
            }
        }

        delete[] coor;

        int voxelidx, num;
        int voxel_num = 0;

        // 2d grid, grid_size[2] is just 1
        int*** coor_to_voxelidx = createArrayInt(grid_size[2], grid_size[1], grid_size[0]);
        for (int i = 0; i < grid_size[2]; i++)
            for (int j = 0; j < grid_size[1]; j++)
                for (int k = 0; k < grid_size[0]; k++)
                    coor_to_voxelidx[i][j][k] = -1;

        for (int i = 0; i < points.size(); ++i) {
            
            if (temp_coors[i][0] == -1) continue;
            voxelidx = coor_to_voxelidx[temp_coors[i][0]][temp_coors[i][1]][temp_coors[i][2]];
            
            // record voxel
            if (voxelidx == -1) {
                voxelidx = voxel_num;
                if (max_voxels != -1 && voxel_num >= max_voxels) continue;
                voxel_num += 1;

                coor_to_voxelidx[temp_coors[i][0]][temp_coors[i][1]][temp_coors[i][2]] = voxelidx;

                for (int k = 0; k < NDim; ++k) {
                    coors[voxelidx][k] = temp_coors[i][k];
                }
            }

            // put points into voxel
            num = num_points_per_voxel[voxelidx];
            if (max_points == -1 || num < max_points) {
                for (int k = 0; k < num_features; ++k) {
                    voxels[voxelidx][num][k] = points[i][k];
                }
                num_points_per_voxel[voxelidx] += 1;
            }
        }

        freeArray(points.size(), NDim, (float**)temp_coors);
        freeArray(grid_size[2], grid_size[1], grid_size[0], (float***)coor_to_voxelidx);

        return voxel_num;
    }

    void pointsCenterLayer(float*** cl, float*** pl1, int* pl2, int l_max, int n_max)
    {
        for (int l = 0; l < l_max; l++)
        {
            // find the center point
            float* sum = new float[n_max];
            memset(sum, 0, n_max * sizeof(float));

            for (int mi = 0; mi < pl2[l]; mi++)
                for (int ni = 0; ni < n_max; ni++)
                    sum[ni] += pl1[l][mi][ni];

            // subtract from position
            for (int m = 0; m < pl2[l]; m++)
            {
                for (int n = 0; n < n_max; n++)
                {
                    cl[l][m][n] = pl1[l][m][n] - (sum[n] / (float) pl2[l]);
                }
            }

            delete[] sum;
        }
    }

    void offsetPillarCenter(float** cl, float*** pl1, int** pl0, int* pl2,
        int l_max, int ind, float vx_size, float offset)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < pl2[l]; m++)
            {
                cl[l][m] = pl1[l][m][ind] - ((float) pl0[l][2 - ind] * vx_size + offset);
            }
        }
    }

    void embeddingLayer(float*** cl, float*** pl1, float*** pl3, float** pl4,
        float ** pl5, float** w0, float* gamma, float* beta, float* mean, float* var,
        int l_max, int m_max, int n_max)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                // features concatenated
                float concat[9];
                concat[0] = pl4[l][m];
                concat[1] = pl5[l][m];
                concat[2] = pl1[l][m][2];
                concat[3] = pl1[l][m][3];
                concat[4] = pl3[l][m][0];
                concat[5] = pl3[l][m][1];
                concat[6] = pl3[l][m][2];
                concat[7] = pl4[l][m];
                concat[8] = pl5[l][m];

                for (int n = 0; n < n_max; n++)
                {
                    // convolve
                    cl[l][m][n] = 0.0f;
                    for (int x = 0; x < 9; x++)
                    {
                        cl[l][m][n] += concat[x] * w0[n][x];
                    }

                    // batch norm
                    cl[l][m][n] = batchNorm(cl[l][m][n], gamma[n], beta[n], mean[n], var[n]);
                    
                    // relu
                    cl[l][m][n] = relu(cl[l][m][n]);
                }
            }
        }
    }

    void maxPoolLayer(float** cl, float*** pl, int l_max, int m_max, int n_max)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                cl[l][m] = pl[l][0][m];
                for (int n = 1; n < n_max; n++)
                {
                    cl[l][m] = fmax(cl[l][m], pl[l][n][m]);
                }
            }
        }
    }

    void pillarScatter(float*** cl, float** pl, int** pl2, int l_max, int m_max)
    {
        for (int l = 0; l < l_max; l++)
        {
            int x = pl2[l][1];
            int y = pl2[l][2];
            for (int m = 0; m < m_max; m++)
            {
                cl[m][x][y] = pl[l][m];
            }
        }
    }

    void conv3Stride2PadLeft(float*** cl, float*** pl, float**** w,
        float* gamma, float* beta, float* mean, float* var,
        int l_max, int m_max, int n_max, int k)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                float s = 0.0f;
                int l0 = l * 2, l1 = l0 + 1, l2 = l0 + 2;
                int m0 = m * 2, m1 = m0 + 1, m2 = m0 + 2;

                // kernel
                for (int n = 0; n < n_max; n++) {
                    s += padLayerUneven(pl, n, l0, m0) * w[k][n][0][0];
                    s += padLayerUneven(pl, n, l0, m1) * w[k][n][0][1];
                    s += padLayerUneven(pl, n, l0, m2) * w[k][n][0][2];
                    s += padLayerUneven(pl, n, l1, m0) * w[k][n][1][0];
                    s += padLayerUneven(pl, n, l1, m1) * w[k][n][1][1];
                    s += padLayerUneven(pl, n, l1, m2) * w[k][n][1][2];
                    s += padLayerUneven(pl, n, l2, m0) * w[k][n][2][0];
                    s += padLayerUneven(pl, n, l2, m1) * w[k][n][2][1];
                    s += padLayerUneven(pl, n, l2, m2) * w[k][n][2][2];
                }

                // batch norm
                s = batchNorm(s, gamma[k], beta[k], mean[k], var[k]);
                // activation
                s = relu(s);

                cl[k][l][m] = s;
            }
        }
    }

    void conv3Stride1PadEven(float*** cl, float*** pl, float**** w,
        float* gamma, float* beta, float* mean, float* var,
        int l_max, int m_max, int n_max, int k)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                float s = 0.0f;
                int l0 = l, l1 = l0 + 1, l2 = l0 + 2;
                int m0 = m, m1 = m0 + 1, m2 = m0 + 2;

                // kernel
                for (int n = 0; n < n_max; n++) {
                    s += padLayerEven(pl, n, l0, m0, l_max, m_max) * w[k][n][0][0];
                    s += padLayerEven(pl, n, l0, m1, l_max, m_max) * w[k][n][0][1];
                    s += padLayerEven(pl, n, l0, m2, l_max, m_max) * w[k][n][0][2];
                    s += padLayerEven(pl, n, l1, m0, l_max, m_max) * w[k][n][1][0];
                    s += padLayerEven(pl, n, l1, m1, l_max, m_max) * w[k][n][1][1];
                    s += padLayerEven(pl, n, l1, m2, l_max, m_max) * w[k][n][1][2];
                    s += padLayerEven(pl, n, l2, m0, l_max, m_max) * w[k][n][2][0];
                    s += padLayerEven(pl, n, l2, m1, l_max, m_max) * w[k][n][2][1];
                    s += padLayerEven(pl, n, l2, m2, l_max, m_max) * w[k][n][2][2];
                }

                // batch norm
                s = batchNorm(s, gamma[k], beta[k], mean[k], var[k]);
                // activation
                s = relu(s);

                cl[k][l][m] = s;
            }
        }
    }

    void convTranspose1Stride1(float*** cl, float*** pl, float**** w,
        float* gamma, float* beta, float* mean, float* var,
        int l_max, int m_max, int n_max, int k)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                float s = 0.0f;

                // kernel
                for (int n = 0; n < n_max; n++) {
                    s += pl[n][l][m] * w[n][k][0][0];
                }

                // batch norm
                s = batchNorm(s, gamma[k], beta[k], mean[k], var[k]);
                // activation
                s = relu(s);

                cl[k][l][m] = s;
            }
        }
    }

    void convTranspose2Stride2(float*** cl, float*** pl, float**** w,
        float* gamma, float* beta, float* mean, float* var,
        int l_max, int m_max, int n_max, int k)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                float s = 0.0f;
                int l0 = l / 2, m0 = m / 2;
                int x = l % 2, y = m % 2;

                // kernel
                for (int n = 0; n < n_max; n++) {
                    s += pl[n][l0][m0] * w[n][k][x][y];
                }

                // batch norm
                s = batchNorm(s, gamma[k], beta[k], mean[k], var[k]);
                // activation
                s = relu(s);

                cl[k][l][m] = s;
            }
        }
    }

    void convTranspose4Stride4(float*** cl, float*** pl, float**** w,
        float* gamma, float* beta, float* mean, float* var,
        int l_max, int m_max, int n_max, int k)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                float s = 0.0f;
                int l0 = l / 4, m0 = m / 4;
                int x = l % 4, y = m % 4;

                // kernel
                for (int n = 0; n < n_max; n++) {
                    s += pl[n][l0][m0] * w[n][k][x][y];
                }

                // batch norm
                s = batchNorm(s, gamma[k], beta[k], mean[k], var[k]);
                // activation
                s = relu(s);

                cl[k][l][m] = s;
            }
        }
    }

    void conv1Stride1Bias(float*** cl, float*** pl0, float*** pl1, float*** pl2,
        float**** w0, float* w1, int l_max, int m_max, int k)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                float s = 0.0f;

                // kernel
                for (int n = 0; n < 128; n++) {
                    s += pl0[n][l][m] * w0[k][n][0][0];
                }
                for (int n = 0; n < 128; n++) {
                    s += pl1[n][l][m] * w0[k][n + 128][0][0];
                }
                for (int n = 0; n < 128; n++) {
                    s += pl2[n][l][m] * w0[k][n + 256][0][0];
                }

                // bias
                s += w1[k];
                cl[k][l][m] = s;
            }
        }
    }

    void conv1Stride1BiasSigmoid(float*** cl, float*** pl0, float*** pl1, float*** pl2,
        float**** w0, float* w1, int l_max, int m_max, int k)
    {
        for (int l = 0; l < l_max; l++)
        {
            for (int m = 0; m < m_max; m++)
            {
                float s = 0.0f;

                // kernel
                for (int n = 0; n < 128; n++) {
                    s += pl0[n][l][m] * w0[k][n][0][0];
                }
                for (int n = 0; n < 128; n++) {
                    s += pl1[n][l][m] * w0[k][n + 128][0][0];
                }
                for (int n = 0; n < 128; n++) {
                    s += pl2[n][l][m] * w0[k][n + 256][0][0];
                }

                // bias
                s += w1[k];

                // sigmoid
                cl[k][l][m] = sigmoid(s);
            }
        }
    }

    void anchorGenerator(float*** cl, int x, int k_max, int l_max)
    {
        const float step_x = (getAnchorRange(x, 3) - getAnchorRange(x, 0)) / (float)(l_max);
        const float step_y = (getAnchorRange(x, 4) - getAnchorRange(x, 1)) / (float)(k_max);

        const float shift_x = step_x / 2.0f;
        const float shift_y = step_y / 2.0f;

        for (int k = 0; k < k_max; k++)
        {
            for (int l = 0; l < l_max; l++)
            {
                cl[k][l][0] = getAnchorRange(x, 0) + step_x * l + shift_x;
                cl[k][l][1] = cl[k][l][0];
                cl[k][l][2] = getAnchorRange(x, 1) + step_y * k + shift_y;
                cl[k][l][3] = cl[k][l][2];
                cl[k][l][4] = getAnchorRange(x, 2);
                cl[k][l][5] = cl[k][l][4];
                cl[k][l][6] = getAnchorSize(x, 0);
                cl[k][l][7] = cl[k][l][6];
                cl[k][l][8] = getAnchorSize(x, 1);
                cl[k][l][9] = cl[k][l][8];
                cl[k][l][10] = getAnchorSize(x, 2);
                cl[k][l][11] = cl[k][l][10];
                cl[k][l][12] = anchor_rotations[0];
                cl[k][l][13] = anchor_rotations[1];
            }
        }
    }

    void anchors2Bboxes(float** cl, float** anchors, float** deltas, int k_max)
    {
        for (int i = 0; i < k_max; i++)
        {
            float da = sqrtf(pow(anchors[i][3], 2) + pow(anchors[i][4], 2));
            float x = deltas[i][0] * da + anchors[i][0];
            float y = deltas[i][1] * da + anchors[i][1];
            float z = deltas[i][2] * anchors[i][5] + anchors[i][2] + anchors[i][5] / 2.0f;
            float w = anchors[i][3] * expf(deltas[i][3]);
            float l = anchors[i][4] * expf(deltas[i][4]);
            float h = anchors[i][5] * expf(deltas[i][5]);

            z = z - h / 2.0f;

            float theta = anchors[i][6] + deltas[i][6];

            cl[i][0] = x;
            cl[i][1] = y;
            cl[i][2] = z;
            cl[i][3] = w;
            cl[i][4] = l;
            cl[i][5] = h;
            cl[i][6] = theta;
        }
    }

    // rotation robust intersection over union, birds eye view
    // b1 - x, y, z, w, l, h, theta
    // b2 - x, y, z, w, l, h, theta
    float RIoU_BEV(float* b1, float* b2)
    {
        //printf("b1\n");
        //for (int i = 0; i < 7; i++)
        //    printf("%lf, ", b1[i]);
        //printf("\n");

        //printf("b2\n");
        //for (int i = 0; i < 7; i++)
        //    printf("%lf, ", b2[i]);
        //printf("\n");

        // 1. center b2 corners onto b1
        float cp[4][2] =
        {
            {b2[0] - b2[3] / 2.0f - b1[0], b2[1] - b2[4] / 2.0f - b1[1]},
            {b2[0] - b2[3] / 2.0f - b1[0], b2[1] + b2[4] / 2.0f - b1[1]},
            {b2[0] + b2[3] / 2.0f - b1[0], b2[1] - b2[4] / 2.0f - b1[1]},
            {b2[0] + b2[3] / 2.0f - b1[0], b2[1] + b2[4] / 2.0f - b1[1]}
        };

        //printf("b2 projected\n");
        //for (int i = 0; i < 4; i++)
        //    printf("%lf,%lf ", cp[i][0], cp[i][1]);
        //printf("\n");

        // 2. rotate b2 corners into b1 axis

        float rcp[4][2];
        float rd = b1[6] - b2[6];
        for (int i = 0; i < 4; i++)
        {
            rcp[i][0] = cosf(rd) * cp[i][0] - sinf(rd) * cp[i][1];
            rcp[i][1] = sinf(rd) * cp[i][0] + cosf(rd) * cp[i][1];
        }

        //printf("b2 rotated\n");
        //for (int i = 0; i < 4; i++)
        //    printf("%lf,%lf ", rcp[i][0], rcp[i][1]);
        //printf("\n");

        // 3. new projected rectangle
        float minX = rcp[0][0];
        float maxX = rcp[0][0];
        float minY = rcp[0][1];
        float maxY = rcp[0][1];
        for (int i = 1; i < 4; i++)
        {
            minX = fmin(minX, rcp[i][0]);
            maxX = fmax(maxX, rcp[i][0]);
            minY = fmin(minY, rcp[i][1]);
            maxY = fmax(maxY, rcp[i][1]);
        }

        //printf("b2 new corners\n");
        //printf("x: %lf - %lf, y: %lf - %lf\n", minX, maxX, minY, maxY);

        // 4. find the intersecting area

        float left = fmax(-b1[3] / 2.0f, minX);
        float right = fmin(b1[3] / 2.0f, maxX);
        float bottom = fmax(-b1[4] / 2.0f, minY);
        float top = fmin(b1[4] / 2.0f, maxY);

        float i1 = 0.0f;
        if (left < right && bottom < top)
        {
            i1 = (right - left) * (top - bottom);
            // printf("b2 area: %lf\n", i1);
        }
        // if it's not even intersecting
        else return 0;

        // 5. repeat for mapping b1 onto b2

        cp[0][0] = b1[0] - b1[3] / 2.0f - b2[0];
        cp[0][1] = b1[1] - b1[4] / 2.0f - b2[1];
        cp[1][0] = b1[0] - b1[3] / 2.0f - b2[0];
        cp[1][1] = b1[1] + b1[4] / 2.0f - b2[1];
        cp[2][0] = b1[0] + b1[3] / 2.0f - b2[0];
        cp[2][1] = b1[1] - b1[4] / 2.0f - b2[1];
        cp[3][0] = b1[0] + b1[3] / 2.0f - b2[0];
        cp[3][1] = b1[1] + b1[4] / 2.0f - b2[1];

        // 6. rotate b1 corners into b2 axis

        rd = b2[6] - b1[6];
        for (int i = 0; i < 4; i++)
        {
            rcp[i][0] = cosf(rd) * cp[i][0] - sinf(rd) * cp[i][1];
            rcp[i][1] = sinf(rd) * cp[i][0] + cosf(rd) * cp[i][1];
        }

        // 7. new projected rectangle
        minX = rcp[0][0];
        maxX = rcp[0][0];
        minY = rcp[0][1];
        maxY = rcp[0][1];
        for (int i = 1; i < 4; i++)
        {
            minX = fmin(minX, rcp[i][0]);
            maxX = fmax(maxX, rcp[i][0]);
            minY = fmin(minY, rcp[i][1]);
            maxY = fmax(maxY, rcp[i][1]);
        }

        // 8. find the intersecting area

        left = fmax(-b2[3] / 2.0f, minX);
        right = fmin(b2[3] / 2.0f, maxX);
        bottom = fmax(-b2[4] / 2.0f, minY);
        top = fmin(b2[4] / 2.0f, maxY);

        float i2 = 0.0f;
        if (left < right && bottom < top)
        {
            i2 = (right - left) * (top - bottom);
        }

        // smallest intersection
        float i_riou = fmin(i1, i2) * fabs(cosf(2 * rd));
        // union area
        float u_riou = fmax(i_riou, b1[3] * b1[4] + b2[3] * b2[4] - i_riou);
        // intersection over union
        return i_riou / u_riou;
    }

    void nonMaxSupression(float** in, std::vector<int> cls, std::vector<int> *keep, int k)
    {
        bool discard = false;
        for (int l = 0; l < 100; l++)
        {
            if (cls[k] != cls[l] || k == l) continue;
            float score = RIoU_BEV(in[k], in[l]);
            if (score > 0.1f && l < k)
            {
                discard = true;
                break;
            }
        }

        if (!discard) (*keep).push_back(k);
    }

    void forwardProp()
    {
        using namespace std;
        vector<thread> threads;

        // filter to region
        input = point_range_filter(input);

        // voxelize to pillars
        int total_voxels = hard_voxelize_cpu(input, l0, l1, l2);

        // offset to points center
        pointsCenterLayer(l3, l1, l2, total_voxels, 3);

        // offsets to pillar centers
        // X
        offsetPillarCenter(l4, l1, l0, l2, total_voxels, 0, voxel_size[0],
            voxel_size[0] / 2.0f + coors_range[0]);
        // Y
        offsetPillarCenter(l5, l1, l0, l2, total_voxels, 1, voxel_size[1],
            voxel_size[1] / 2.0f + coors_range[1]);

        // embedding, convolve, batch norm, relu
        embeddingLayer(l6, l1, l3, l4, l5, const0, const1, const2, rm0, rv0,
            total_voxels, max_points, 64);

        // max pool
        maxPoolLayer(l7, l6, total_voxels, 64, max_points);
        
        // pillar scatter
        pillarScatter(l8, l7, l0, total_voxels, 64);

        // conv + batch norm + relu
        for (int k = 0; k < 64; k++) {
            thread t(&pillar::conv3Stride2PadLeft, this, l9, l8, const3, const4, const5,
                rm1, rv1, 248, 216, 64, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 64; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l10, l9, const6, const7, const8,
                rm2, rv2, 248, 216, 64, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 64; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l11, l10, const9, const10, const11,
                rm3, rv3, 248, 216, 64, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 64; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l12, l11, const12, const13, const14,
                rm4, rv4, 248, 216, 64, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::conv3Stride2PadLeft, this, l13, l12, const15, const16, const17,
                rm5, rv5, 124, 108, 64, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l14, l13, const18, const19, const20,
                rm6, rv6, 124, 108, 128, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l15, l14, const21, const22, const23,
                rm7, rv7, 124, 108, 128, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l16, l15, const24, const25, const26,
                rm8, rv8, 124, 108, 128, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l17, l16, const27, const28, const29,
                rm9, rv9, 124, 108, 128, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l18, l17, const30, const31, const32,
                rm10, rv10, 124, 108, 128, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 256; k++) {
            thread t(&pillar::conv3Stride2PadLeft, this, l19, l18, const33, const34, const35,
                rm11, rv11, 62, 54, 128, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 256; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l20, l19, const36, const37, const38,
                rm12, rv12, 62, 54, 256, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 256; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l21, l20, const39, const40, const41,
                rm13, rv13, 62, 54, 256, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 256; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l22, l21, const42, const43, const44,
                rm14, rv14, 62, 54, 256, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 256; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l23, l22, const45, const46, const47,
                rm15, rv15, 62, 54, 256, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv + batch norm + relu
        for (int k = 0; k < 256; k++) {
            thread t(&pillar::conv3Stride1PadEven, this, l24, l23, const48, const49, const50,
                rm16, rv16, 62, 54, 256, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv transpose + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::convTranspose1Stride1, this, l25, l12, const51, const52, const53,
                rm17, rv17, 248, 216, 64, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv transpose + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::convTranspose2Stride2, this, l26, l18, const54, const55, const56,
                rm18, rv18, 248, 216, 128, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // conv transpose + batch norm + relu
        for (int k = 0; k < 128; k++) {
            thread t(&pillar::convTranspose4Stride4, this, l27, l24, const57, const58, const59,
                rm19, rv19, 248, 216, 256, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // bbox_cls_pred
        // conv + bias
        for (int k = 0; k < 18; k++) {
            thread t(&pillar::conv1Stride1BiasSigmoid, this, l28, l25, l26, l27, const60, const61,
                248, 216, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // bbox_pred
        // conv + bias
        for (int k = 0; k < 42; k++) {
            thread t(&pillar::conv1Stride1Bias, this, l29, l25, l26, l27, const62, const63,
                248, 216, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // bbox_dir_cls_pred
        // conv + bias
        for (int k = 0; k < 12; k++) {
            thread t(&pillar::conv1Stride1Bias, this, l30, l25, l26, l27, const64, const65,
                248, 216, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        anchorGenerator(l31, 0, 248, 216);
        anchorGenerator(l32, 1, 248, 216);
        anchorGenerator(l33, 2, 248, 216);

        // bbox_cls_pred remapped
        // reshape2to3(l28, 3, x, y)
        // bbox_pred remapped
        // reshape2to3(l29, 7, x, y)
        // bbox_dir_cls_pred remapped
        // reshape2to3(l30, 2, x, y)

        // bbox_dir_cls_pred_max
        // l30[x][0] > l30[x][1] ? 0 : 1;
        
        std::vector<int> l35b; // save class labels

        // find the max class for each entry and save the index
        for (int i = 0; i < 321408; i++)
        {
            l34.push_back(reshape2to3(l28, 3, i, 0));
            l35.push_back(i);
            l35b.push_back(0);
            for (int j = 1; j < 3; j++)
            {
                if (reshape2to3(l28, 3, i, j) > l34[i])
                {
                    l34[i] = reshape2to3(l28, 3, i, j);
                    l35b[i] = j;
                }
            }
        }
        
        auto p = sort_permutation(l34,
            [](float const& a, float const& b) { return a > b; });

        apply_permutation_in_place(l34, p);
        apply_permutation_in_place(l35, p);
        apply_permutation_in_place(l35b, p);

        // get the top 100
        for (int i = 0; i < 100; i++)
        {
            // bbox_cls_pred_inds
            for (int j = 0; j < 3; j++)
                l36[i][j] = reshape2to3(l28, 3, l35[i], j);
            // bbox_pred_inds
            for (int j = 0; j < 7; j++)
                l37[i][j] = reshape2to3(l29, 7, l35[i], j);
            // bbox_dir_cls_pred_inds
            l38[i] = (reshape2to3(l30, 2, l35[i], 0) > reshape2to3(l30, 2, l35[i], 1)) ? 0 : 1;
            // bbox_anchors_inds
            for (int j = 0; j < 7; j++)
                l39[i][j] = anchor2to3(l35[i], j);
        }

        anchors2Bboxes(l40, l39, l37, 100);

        // nms
        std::vector<int> keep;
        for (int k = 0; k < 100; k++) {
            thread t(&pillar::nonMaxSupression, this, l40, l35b, &keep, k);
            threads.push_back(move(t));
        }
        for (auto& th : threads) th.join();
        threads.clear();

        // output
        for (int i = 0; i < keep.size(); i++)
        {
            float* bbox = l40[keep[i]];
            bbox[6] = limit_period(bbox[6], 1.0f, 3.1415927f);
            bbox[6] += (float)(1 - l38[keep[i]]) * 3.1415927f;
            ret_bboxes.push_back(bbox);
            ret_labels.push_back(l35b[keep[i]]);
            ret_scores.push_back(l36[keep[i]][l35b[keep[i]]]);
        }

        for (int i = 0; i < keep.size(); i++)
        {
            printf("class: %d, score: %lf, bbox: ", ret_labels[i], ret_scores[i]);
            for (int j = 0; j < 7; j++)
                printf("%lf ", ret_bboxes[i][j]);
            printf("\n");
        }
    }
};

int main()
{
    std::string PATHWEIGHTS = "D:/Storage/3dObjDetect/PointPillars/pretrained/pillar.bytes";
    std::string PATHMEANVAR = "D:/Storage/3dObjDetect/PointPillars/pretrained/rmv.bytes";
    std::string PATHINPUT = "D:/Storage/3dObjDetect/PointPillars/dataset/kitti/testing/velodyne/000000.bin";

    pillar pointPillar = pillar(PATHWEIGHTS, PATHMEANVAR, PATHINPUT);
    pointPillar.forwardProp();

    getchar();
}