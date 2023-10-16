#include "node.h"

#include <string>
#include <vector>
#include <iostream>

void Node::delete_re()
{
	for(int i = 0; i < children.size(); i++)
	{ delete children[i]; }
}

Node::Node(std::string name, std::string data)
{
	this->name = name;
	this->data = data;
	children = std::vector<Node*>();
}

Node::~Node()
{ delete_re(); }

Node* node_lookup(Node* node, std::string name)
{
	if(node != nullptr)
	{
		if(node->name == name)
		{ return node; }

		for(Node* child : node->children)
		{
			Node* candidate = node_lookup(child, name);
			if(candidate != nullptr)
			{ return candidate; }
		}
	}

	return nullptr;
}

std::vector<std::string> node_flatten(Node* node)
{
	std::vector<std::string> data = std::vector<std::string>();

	if(node != nullptr)
	{
		if(node->data != "")
		{ data.push_back(node->data); }
		else
		{
			for(Node* child : node->children)
			{
				std::vector<std::string> child_data = node_flatten(child);
				data.insert(data.end(), child_data.begin(), child_data.end());
			}
		}
	}
	
	return data;
}

void node_populate(Node* node, std::vector<std::string>& items)
{
	for(int i = 0; i < node->children.size(); i++)
	{ delete node->children[i]; }
	node->children = std::vector<Node*>();
	for(int i = 0; i < items.size(); i++)
	{ node->children.push_back(new Node("item", items[i])); }
}

void node_print(Node* node)
{
	if(node == nullptr)
	{
		std::cerr << "<>" << std::endl;
		return;
	}

	std::cerr << "<" << node->name << "> (" << node->data << ")" << std::endl;
	for(Node* child : node->children)
	{
		std::cerr << "\t";
		node_print(child);
	}
}
