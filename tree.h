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
		bool terminal;
		std::vector<Node*> children;

		bool is_terminated()
		{
			for(int i = 0; i < children.size(); i++)
			{
				if(children[i]->terminal)
				{ return true; }
			}
			return false;
		}

		Node(std::string data, bool terminal)
		{
			this->data = data;
			this->terminal = terminal;
			children = std::vector<Node*>();
		}

		~Node()
		{ delete_re(); }
};
