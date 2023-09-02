#include "doc.h"

#include <vector>
#include <fstream>
#include <sstream>
#include <iostream>
#include <cctype>

std::string CSVDoc::read(std::string path)
{
	std::ifstream file = std::ifstream(path);
	std::stringstream buffer;
	buffer << file.rdbuf();
	file.close();
	return buffer.str();
}

std::string CSVDoc::read(Node* graph)
{
	if(graph->children.size() > 0)
	{
		return
		graph->data + ',' +
		read(graph->children.back());
	}
	else
	{ return graph->data; }
}

std::vector<std::string> CSVDoc::lex(std::string text)
{
	std::vector<std::string> tokens = std::vector<std::string>();

	int start = 0;
	for(int i = 0; i < text.size(); i++)
	{
		if(text[i] == ',' || text[i] == '\n')
		{
			tokens.push_back(text.substr(start, i-start));
			start = i+1;
		}
	}

	return tokens;
}

bool CSVDoc::validate()
{ return true; }

Node* CSVDoc::graph()
{
	if(tokens.size() == 0)
	{ return nullptr; }

	Node* graph = new Node("", false);

	Node* parent = graph;
	for(std::string token : tokens)
	{
		Node* child = new Node(token, false);
		parent->children.push_back(child);
		parent = child;
	}
	parent->terminal = true;

	Node* old = graph;
	graph = graph->children.back();
	old->children.pop_back();

	delete old;
	return graph;
}

void CSVDoc::write(std::string path)
{
	std::ofstream file = std::ofstream(path);
	file << text;
	file.close();
}

std::string CSVDoc::dump()
{
	std::string out = text;
	out += "---\n";
	for(std::string token : tokens)
	{ out += token + '\n'; }
	out += "---\n";
	out += read(graph());
	return out;
}
		
CSVDoc::CSVDoc(std::string path)
{
	text = read(path);
	tokens = lex(text);
}

CSVDoc::CSVDoc(Node* graph)
{
	text = read(graph);
	tokens = lex(text);
}

