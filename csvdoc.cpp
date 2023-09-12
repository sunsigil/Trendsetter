#include "doc.h"

#include <vector>
#include <fstream>
#include <sstream>
#include <iostream>
#include <cctype>

std::string CSVDoc::read(Node* graph)
{
	if(graph->children.size() > 0)
	{
		return
		graph->data + ',' +
		read(graph->children.back());
	}
	else
	{ return graph->data + '\n'; }
}

std::vector<std::string> CSVDoc::lex(std::string text)
{
	std::vector<std::string> tokens = std::vector<std::string>();

	int start = 0;
	for(int i = 0; i < text.size(); i++)
	{
		if(text[i] == ',' || i == text.size()-1)
		{
			tokens.push_back(text.substr(start, i-start));
			start = i+1;
		}
	}

	return tokens;
}

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

CSVDoc::CSVDoc(std::string path)
{
	text = Doc::read(path);
	tokens = lex(text);
}

CSVDoc::CSVDoc(Node* graph)
{
	text = read(graph);
	tokens = lex(text);
}

