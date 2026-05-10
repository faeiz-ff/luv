#include <stdio.h>
#define NOB_IMPLEMENTATION
#include "nob.h"

#define BUILD_FOLDER "./build/"
#define SRC_FOLDER "./src/"

int all_src_files_to_txt(char* filename) 
{
    Nob_Cmd cmd = {0};
    Nob_Chain chain = {0};
    if (!nob_chain_begin(&chain)) return 1;
    {
        nob_cmd_append(&cmd, "find", SRC_FOLDER);
        if (!nob_chain_cmd(&chain, &cmd)) return 1;

        nob_cmd_append(&cmd, "grep", "\\.c");
        if (!nob_chain_cmd(&chain, &cmd)) return 1;

        nob_cmd_append(&cmd, "tee", filename);
        if (!nob_chain_cmd(&chain, &cmd)) return 1;
    }
    if (!nob_chain_end(&chain)) return 1;
    return 0;
}

int append_srcs(Nob_Cmd *cmd) 
{

    if (all_src_files_to_txt(BUILD_FOLDER"files.txt")) return 0;

    FILE* fptr;
    fptr = fopen(BUILD_FOLDER"files.txt", "r");

    if (fptr == NULL) {
        printf("[ERROR] can't read "BUILD_FOLDER"files.txt");
        return 0;
    }

    char buff[100];
    
    while(fgets(buff, 100, fptr)) {
        char *ch = buff + strlen(buff);
        *(ch-1) = '\0';

        String_Builder sb = {0};
        nob_sb_append_cstr(&sb, buff);

        nob_cmd_append(cmd, sb.items);
        // this leaks memory but whatever its in the build phase
        // sb.items should've been freed idk how
        // TODO: learn to fix this
    }

    fclose(fptr);
    return 1;
}

int main(int argc, char **argv) 
{
    NOB_GO_REBUILD_URSELF(argc, argv);
    if (!nob_mkdir_if_not_exists(BUILD_FOLDER)) return 1;

    Nob_Cmd cmd = {0};

    nob_cmd_append(&cmd, "cc", "-Wall", "-Wextra", "-o", BUILD_FOLDER"main");

    if (!append_srcs(&cmd)) return 1;
    if (!nob_cmd_run_sync_and_reset(&cmd)) return 1;

    nob_cmd_append(&cmd, BUILD_FOLDER "main");

    if (!nob_cmd_run_sync_and_reset(&cmd)) return 1;

    return 0;
}
