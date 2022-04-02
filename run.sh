flex -o main.yy.cpp main.lex &&
g++ -lfl -o main main.yy.cpp &&
./main < input.txt
