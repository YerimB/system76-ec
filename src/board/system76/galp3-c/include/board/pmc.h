#ifndef _BOARD_PMC_H
#define _BOARD_PMC_H

#include <ec/pmc.h>

void pmc_init(void);
void pmc_event(struct Pmc * pmc);

#endif // _BOARD_PMC_H
