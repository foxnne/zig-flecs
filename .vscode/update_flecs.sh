echo "----- cd src/c"
cd src/c

echo "----- translate-c the old flecs.h file"
zig translate-c -lc flecs.h > ../raw_old.zig

echo "----- download flecs.h and flecs.c"
curl -O https://raw.githubusercontent.com/SanderMertens/flecs/master/flecs.h
curl -O https://raw.githubusercontent.com/SanderMertens/flecs/master/flecs.c

echo "----- translate-c the new flecs.h file"
zig translate-c -lc flecs.h > ../raw_new.zig

echo "----- done"