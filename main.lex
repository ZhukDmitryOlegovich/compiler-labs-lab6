%{
	#include <iomanip>
	#include <iostream>
	#include <unordered_map>
	#include <regex>
	#include <string>

	using std::cout;
	using std::endl;
	using std::ostream;
	using std::regex;
	using std::regex_replace;
	using std::setw;
	using std::string;

	extern "C" int yylex();

	struct Position
	{
		int line, column;
		friend ostream &operator<<(ostream &os, const Position &p);
	} start, finish, current({1, 1});

	ostream &operator<<(ostream &os, const Position &p)
	{
		return os << '(' << setw(2) << p.line << ',' << setw(2) << p.column << ')';
	}

	ostream &label(ostream & os, const string &name)
	{
		return os << name << ' ' << start << '-' << finish << ':' << ' ';
	}

	#define YY_USER_ACTION          \
	{                               \
		start = current;            \
		auto xxtext = yytext;       \
		for (; xxtext[0]; xxtext++) \
		{                           \
			if (xxtext[0] == '\n')  \
			{                       \
				current.line++;     \
				current.column = 0; \
			}                       \
			current.column++;       \
		}                           \
		finish = current;           \
	}
%}
%%
(0|1+) label(cout, "NUMBER") << (yytext[0] == '0' ? 0 : strlen(yytext)) << endl;
["]([^\\\n"]|\\[tn"])*["] {
	string yystr(yytext);
	yystr = yystr.substr(1, yystr.size() - 2);
	yystr = regex_replace(yystr, regex("\\\\\""), "\"");
	yystr = regex_replace(yystr, regex("\\\\n"), "\n");
	yystr = regex_replace(yystr, regex("\\\\t"), "\t");
	label(cout, "REGSTR") << '{' << yystr << '}' << '=' << yystr.size() << endl;
}
[@]["]([^"]|["]["])*["] { // "
	string yystr(yytext);
	yystr = yystr.substr(2, yystr.size() - 3);
	yystr = regex_replace(yystr, regex("\"\""), "\"");
	label(cout, "LITSTR") << '{' << yystr << '}' << '=' << yystr.size() << endl;
}
[ \n\t]
. label(cout, "ERROR ") << '{' << yytext << '}' << '=' << +yytext[0] << endl;
%%
