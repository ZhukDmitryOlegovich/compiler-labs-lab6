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

	struct position
	{
		int line, column;
		friend ostream &operator<<(ostream &os, const position &p);
	} start, finish, current({1, 1});

	ostream &operator<<(ostream &os, const position &p)
	{
		return os << '(' << setw(2) << p.line << ',' << setw(2) << p.column << ')';
	}

	ostream &label(ostream & os, const string &name)
	{
		return os << name << ' ' << start << '-' << finish << ':' << ' ';
	}

	struct smart_string
	{
		const string &v;
		friend ostream &operator<<(ostream &os, const smart_string &s);
	};
	ostream &operator<<(ostream &os, const smart_string &s)
	{
		os << '{';

		for (auto ch : s.v)
		{
			switch (ch)
			{
			case '\\': os << "\\\\"; break;
			case '\n': os << "\\n"; break;
			case '\t': os << "\\t"; break;
			case '{': os << "\\{"; break;
			case '}': os << "\\}"; break;
			default: os << ch;
			}
		}

		return os << '}' << '=' << s.v.size();
	}

#define YY_USER_ACTION              \
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
	yystr = regex_replace(yystr, regex(R"(\\")"), "\"");
	yystr = regex_replace(yystr, regex(R"(\\n)"), "\n");
	yystr = regex_replace(yystr, regex(R"(\\t)"), "\t");
	label(cout, "REGSTR") << smart_string({yystr}) << endl;
}
[@]["]([^"]|["]["])*["] { // "
	string yystr(yytext);
	yystr = yystr.substr(2, yystr.size() - 3);
	yystr = regex_replace(yystr, regex(R"("")"), "\"");
	label(cout, "LITSTR") << smart_string({yystr}) << endl;
}
[ \n\t]
. label(cout, "ERROR ") << '{' << yytext << '}' << '=' << +yytext[0] << endl;
%%
