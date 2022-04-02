%{
	#include <iostream>
	#include <unordered_map>
	#include <regex>
	#include <string>

	using std::cout;
	using std::endl;
	using std::regex;
	using std::regex_replace;
	using std::string;

	extern "C" int yylex();

	struct Position
	{
		int line, column;

		Position() {}

		Position(int _line, int _column) : line(_line), column(_column) {}

		void print()
		{
			cout << "(" << (line < 10 ? " " : "") << line << ":" << (column < 10 ? " " : "") << column << ")";
		}
	};

	int curid = 1;
	std::unordered_map<string, int> idents;
	Position start, finish;
	Position current(1, 1);

	#define YY_USER_ACTION          \
	{                               \
		start = current;            \
		auto xxtext = yytext;       \
		for (; yytext[0]; yytext++) \
		{                           \
			if (yytext[0] == '\n')  \
			{                       \
				line = 1;           \
				column = 0;         \
			}                       \
			column++;               \
		}                           \
		finish = current;           \
	}
%}
%%
(0|1+) {
	cout << "NUMBER ";
	start.print();
	cout << '-';
	finish.print();
	cout << ' ' << (yytext[0] == '0' ? 0 : strlen(yytext)) << endl;
}
["]([^\\\n"]|\\[tn"])*["] {
	cout << "REGSTR ";
	start.print();
	cout << '-';
	finish.print();
	string yystr(yytext);
	yystr = yystr.substr(1, yystr.size() - 2);
	yystr = regex_replace(yystr, regex("\\\\\""), "\"");
	yystr = regex_replace(yystr, regex("\\\\n"), "\n");
	yystr = regex_replace(yystr, regex("\\\\t"), "\t");
	cout << " {" << yystr << '}' << endl;
}
[ \n\t]
. {
	cout << "Unexpected char at line: " << start.line << ", column: " << start.column << endl;
}
%%
