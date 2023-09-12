#include "doc.h"

#include <vector>
#include <fstream>
#include <sstream>
#include <iostream>
#include <cctype>

std::string clean_token(std::string token)
{
	int start, end;
	for(start = 0; start < token.size(); start++)
	{
		if(!isspace(token[start]))
		{ break; }
	}
	for(end = token.size()-1; end >= start; end--)
	{
		if(!isspace(token[end]))
		{ break; }
	}
	return token.substr(start, end-start+1);
}

bool is_tag(std::string text, int i)
{
	if(text[i++] != '<')
	{ return false; }

	while(i < text.size())
	{
		if(text[i] == '<')
		{ return false; }
		else if(text[i] == '>')
		{ return true; }
		i++;
	}
	
	return false;
}

std::string read_tag(std::string text, int i)
{
	int start = i+1;
	while(i < text.size() && text[i] != '>')
	{ i++; }
	int count = i-start;

	return text.substr(start, count);
}

std::string read_helper(Node* node, int level)
{
	std::string text = "";
	for(int i = 0; i < level; i++)
	{ text += '\t'; }

	if(!node->terminal)
	{
		text += "<" + node->data + ">\n";

		for(int i = 0; i < node->children.size(); i++)
		{ text += read_helper(node->children[i], level+1); }
		
		for(int i = 0; i < level; i++)
		{ text += '\t'; }
		text += "</" + node->data + ">\n";
	}
	else if(clean_token(node->data).size() == 0)
	{ text += "0\n"; }
	else
	{ text += node->data + "\n"; }

	return text;
}

std::string XMLDoc::read(Node* graph)
{ return read_helper(graph, 0); }

std::vector<std::string> XMLDoc::lex(std::string text)
{
	std::vector<std::string> tokens = std::vector<std::string>();
	enum Mode { TAG, CONTENT } state = CONTENT;
	std::string token = "";
	
	for(int idx = 0; idx < text.size(); idx++)
	{
		switch(state)
		{
			case TAG:
				if(text[idx] == '>')
				{
					tokens.push_back("t:"+token);
					token = "";
					state = CONTENT;
				}
				else
				{ token += text[idx]; }
			break;

			case CONTENT:
				if(text[idx] == '<')
				{
					token = clean_token(token);
					if(token.size() > 0)
					{ tokens.push_back("c:"+token); }
					token = "";
					state = TAG;
				}
				else
				{ token += text[idx]; }
			break;
		}
	}

	return tokens;
}

bool XMLDoc::validate()
{
	std::vector<std::string> stack = std::vector<std::string>();
	
	for(int i = 0; i < text.size(); i++)
	{
		if(is_tag(text, i))
		{
			std::string tag = read_tag(text, i);
			if(tag[0] == '/')
			{
				if(stack.size() == 0)
				{ return false; }

				std::string last = stack.back();
				stack.pop_back();
				if(last != tag.substr(1, tag.size()-1))
				{ return false; }
			}
			else
			{ stack.push_back(tag); }
		}
	}

	return stack.size() == 0;
}

Node* XMLDoc::graph()
{
	std::vector<Node*> tree = std::vector<Node*>();
	Node* graph = nullptr;
	
	for(int i = 0; i < tokens.size(); i++)
	{
		std::string prefix = tokens[i].substr(0,2);
		std::string payload = tokens[i].substr(2);
		Node* node;

		switch(prefix[0])
		{
			case 't':
				if(payload[0] == '/')
				{
					graph = tree.back();
					tree.pop_back();
				}
				else
				{
					node = new Node(payload, false);
					if(tree.size() > 0)
					{ tree.back()->children.push_back(node); }
					tree.push_back(node);
				}
			break;

			case 'c':
				node = new Node(payload, true);
				tree.back()->children.push_back(node);
			break;
		}
	}

	return graph;
}

XMLDoc::XMLDoc(std::string path)
{
	text = Doc::read(path);
	tokens = lex(text);
}

XMLDoc::XMLDoc(Node* graph)
{
	text = read(graph);
	tokens = lex(text);
}

