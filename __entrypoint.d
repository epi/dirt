module __entrypoint;

extern(C):
//__gshared void * _Dmodule_ref;
int _Dmain(char[][] args);
int _d_run_main(int argc, char **argv, void* mainFunc);

