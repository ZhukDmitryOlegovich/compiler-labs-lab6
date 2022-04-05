%{
	#include <iomanip>
	#include <iostream>
	#include <unordered_map>
	#include <regex>
	#include <string>
	#include <vector>

	using std::cout;
	using std::endl;
	using std::ostream;
	using std::regex;
	using std::regex_replace;
	using std::setw;
	using std::string;

	extern "C" int yylex();

	struct pos {
		int line, column;
		friend ostream &operator<<(ostream &os, const pos &p);
	} start({1, 1}), finish, current({1, 1});

	struct Token {
		public:
		enum { STR, INT, ERR } type;
		union {
			int i;
			string s;
		};
		pos start, finish;

		Token(const Token& tu) : type(tu.type),  start(tu.start), finish(tu.finish) {
			switch (tu.type) {
				case ERR: 
				case STR: s = tu.s; break;
				case INT: i = tu.i; break;
			}
		}

		explicit Token(int val, pos st, pos fin) 
			: type(INT), i(val), start(st), finish(fin) { }
  		explicit Token(const string& val, pos st, pos fin, bool is_err = false) 
			: type(is_err ? ERR : STR), s(val), start(st), finish(fin) { }

		~Token() {
			switch (type) {
				case ERR: 
				case STR: s.~string(); break;
				case INT: break;
			}
		}
	};

	std::vector<Token> tokens;

	ostream &operator<<(ostream &os, const pos &p) {
		return os << '(' << setw(2) << p.line << ',' << setw(2) << p.column << ')';
	}

	ostream &label(ostream &os, const string &name, const Token &t) {
		return os << name << ' ' << t.start << '-' << t.finish << ':' << ' ';
	}

	struct escape_and_eq {
		const string &v;
		friend ostream &operator<<(ostream &os, const escape_and_eq &s);
	};

	ostream &operator<<(ostream &os, const escape_and_eq &s) {
		os << '{';

		for (auto ch : s.v) {
			switch (ch) {
				case '\\': os << R"(\\)"; break;
				case '\n': os << R"(\n)"; break;
				case '\t': os << R"(\t)"; break;
				case '{':  os << R"(\{)"; break;
				case '}':  os << R"(\})"; break;
				default:   os << ch;
			}
		}

		return os << '}' << '=' << s.v.size();
	}

	#define YY_USER_ACTION { \
		finish = current; \
		for (auto xxtext = yytext; xxtext[0]; xxtext++) { \
			if (xxtext[0] == '\n') { \
				current.line++; \
				current.column = 0; \
			} \
			current.column++; \
		} \
	}

	string ans;
	enum { EMP, REG, LIT } state = EMP;
%}
%%
(0|1+) {
	if (state == EMP) {
		tokens.push_back(Token(yytext[0] == '0' ? 0 : strlen(yytext), finish, current));
	} else {
		ans += yytext;
	}
}
["]{2} { // "
	if (state == EMP) {
		tokens.push_back(Token("", finish, current));
	} else if (state == REG) {
		tokens.push_back(Token(ans, start, pos({current.line, current.column - 1})));
		ans = "";
	} else if (state == LIT) {
		ans += '"';
	}
}
["] { // "
	if (state == EMP) {
		state = REG;
		start = finish;
		ans = "";
	} else if (state == REG || state == LIT) {
		tokens.push_back(Token(ans, start, current));
		state = EMP;
	}
}
[@]["]{2} { // "
	if (state == EMP) {
		tokens.push_back(Token("", finish, current));
	} else if (state == REG) {
		tokens.push_back(Token(ans + '@', start, pos({current.line, current.column - 1})));
		start = pos({current.line, current.column - 1});
		ans = "";
	} else if (state == LIT) {
		ans += "@\"";
	}
}
[@]["] { // "
	if (state == EMP) {
		state = LIT;
		start = finish;
		ans = "";
	} else if (state == REG || state == LIT) {
		tokens.push_back(Token(ans + '@', start, current));
		state = EMP;
	}
}
\\["]{2} { // "
	if (state == EMP) {
		tokens.push_back(Token(ans + yytext + '%', start, current, true));
	} else if (state == REG) {
		tokens.push_back(Token(ans + '"', start, current));
		state = EMP;
	} else if (state == LIT) {
		ans += R"(\")";
	}
}
\\[tn"] { // "
	if (state == EMP) {
		tokens.push_back(Token(ans + yytext + '%', start, current, true));
	} else if (state == REG) {
		switch (yytext[1]) {
			case 'n': ans += '\n'; break;
			case 't': ans += '\t'; break;
			case '"': ans += '\"'; break;
		}
	} else if (state == LIT) {
		if (yytext[1] == '"') {
			tokens.push_back(Token(ans + '\\', start, current));
			state = EMP;
		} else {
			ans += yytext;
		}
	}
}
[ \n\t] {
	if (state == EMP) {
		
	} else if (state == REG) {
		if (yytext[0] == '\n') {
			tokens.push_back(Token(ans + yytext + '%', start, current, true));
			state = EMP;
		} else  {
			ans += yytext;
		}
	} else if (state == LIT) {
		ans += yytext;
	}
}
. {
	if (state == EMP) {
		tokens.push_back(Token(yytext, finish, current, true));
	} else if (state == REG || state == LIT) {
		ans += yytext;
	}
}
%%
int main() {
	yylex();
	for (Token& t : tokens) {
		if (t.type == Token::INT) {
			label(cout, "INT", t) << t.i << endl;
		} else {
			label(cout, t.type == Token::STR ? "STR" : "ERR", t) << escape_and_eq({t.s}) << endl;
		}
	}
}
