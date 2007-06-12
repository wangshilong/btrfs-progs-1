#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kerncompat.h"
#include "hash.h"

int main() {
	u64 result;
	int ret;
	char line[255];
	char *p;
	while(1) {
		p = fgets(line, 255, stdin);
		if (!p)
			break;
		if (strlen(line) == 0)
			continue;
		if (line[strlen(line)-1] == '\n')
			line[strlen(line)-1] = '\0';
		ret = btrfs_name_hash(line, strlen(line), &result);
		BUG_ON(ret);
		printf("hash returns %llu\n", (unsigned long long)result);
	}
	return 0;
}
