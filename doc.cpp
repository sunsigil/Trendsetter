#include "doc.h"

#include <vector>
#include <fstream>
#include <sstream>
#include <iostream>
#include <cctype>

std::string Doc::read(std::string path)
{
	std::ifstream file = std::ifstream(path);
	std::stringstream buffer;
	buffer << file.rdbuf();
	file.close();
	return buffer.str();
}

std::string Doc::read(Node* graph)
{
	return graph->data;
}

std::vector<std::string> Doc::lex(std::string text)
{
	return std::vector<std::string>{text};
}

bool Doc::validate()
{ return true; }

Node* Doc::graph()
{
	return new Node(text, true);
}

void Doc::write(std::string path)
{
	std::ofstream file = std::ofstream(path);
	file << text;
	file.close();
}

std::string Doc::dump()
{
	std::string out = text;
	out += "---\n";
	for(std::string token : tokens)
	{ out += token + '\n'; }
	out += "---\n";
	out += read(graph());
	return out;
}

Doc::Doc()
{
	text = "";
	tokens = std::vector<std::string>();
}
		
Doc::Doc(std::string path)
{
	text = read(path);
	tokens = lex(text);
}

Doc::Doc(Node* graph)
{
	text = read(graph);
	tokens = lex(text);
}

