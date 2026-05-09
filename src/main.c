#include <stddef.h>
#include <stddef.h>
#include <stdio.h>

#define LUV_NO_PREFIX
#include "utils/string_builder.h"
#include "utils/string_view.h"

int main() 
{
    String_Builder sb = {0};

    char buf[100];
    FILE *file;
    file = fopen("./build/files.txt", "r");
    
    if (file == NULL) {
        printf("Cant found file\n");
        return 1;
    }

    while (fgets(buf, 100, file)) {
        sb_append_cstr(&sb, buf);
    }

    String_View sv = {0};
    sv_from_cstr(&sv, sb.items);
    sv_print(&sv);

    fclose(file);
    sb_deinit(&sb);

    return 0;
}

