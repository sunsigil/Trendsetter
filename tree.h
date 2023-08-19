#include <string>
#include <vector>

class Node
{
	private:
		void delete_re()
		{
			for(int i = 0; i < children.size(); i++)
			{ delete children[i]; }
		}

	public:
		std::string data;
		std::vector<Node*> children;

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
