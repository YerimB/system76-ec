#include <scratch/pmc.h>

#define PMC(NUM) { \
    .status = &PM ## NUM ## STS, \
    .data_out = &PM ## NUM ## DO, \
    .data_in = &PM ## NUM ## DI, \
    .control = &PM ## NUM ## CTL, \
}

struct Pmc __code PMC_1 = PMC(1);

uint8_t pmc_status(struct Pmc * pmc) {
    return *(pmc->status);
}

uint8_t pmc_read(struct Pmc * pmc) {
    return *(pmc->data_in);
}

bool pmc_write(struct Pmc * pmc, uint8_t data) {
    while (pmc_status(pmc) & PMC_STS_OBF) {}
    *(pmc->data_out) = data;
    return true;
}