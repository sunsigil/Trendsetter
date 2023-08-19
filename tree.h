#include <string>
#include <vector>
#include <fstream>

class Node
{
	private:
		std::vector<Node*> children;

		void serialize_re(std::ofstream& stream, int level)
		{
			for(int i = 0; i < level; i++)
			{ stream << '\t'; }
			if(children.size() != 0)
			{
				stream << "<" << data << ">" << std::endl;
				for(int i = 0; i < children.size(); i++)
				{ children[i]->serialize_re(stream, level+1); }
				for(int i = 0; i < level; i++)
				{ stream << '\t'; }
				stream << "</" << data << ">" << std::endl;
			}
			else
			{ stream << data << std::endl; }
		}

		void delete_re()
		{
			for(int i = 0; i < children.size(); i++)
			{ delete children[i]; }
		}
	public:
		std::string data;
		std::string get_data() { return data; }
		int child_count() { return children.size(); }
		void add_child(Node* child) { children.push_back(child); }
		Node* get_child(int i)
		{
			if(i < 0 || i >= children.size())
			{ return nullptr; }
			return children.at(i);
		}

		void serialize(std::string path)
		{
			std::ofstream stream = std::ofstream(path);
			serialize_re(stream, 0);
			stream.close();
		}

		Node(std::string data)
		{
			this->data = data;
			children = std::vector<Node*>();
		}
		Node(std::string data, std::vector<Node*> children)
		{
			this->data = data;
			this->children = children;
		}
		~Node()
		{ delete_re(); }
};
