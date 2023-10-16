#pragma once

#include <string>
#include <vector>

class Node
{
	private:
		void delete_re();

	public:
		std::string name;
		std::string data;
		std::vector<Node*> children;

		Node(std::string name, std::string data);
		~Node();
};

Node* node_lookup(Node* node, std::string name);
std::vector<std::string> node_flatten(Node* node);
void node_populate(Node* node, std::vector<std::string>& items);
void node_print(Node* node);
