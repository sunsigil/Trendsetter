#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <iostream>
#include <cctype>

class Doc
{
	private:
		std::string text;

		bool is_tag(int i)
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

		std::string read_tag(int i)
		{
			int start = i+1;
			while(i < text.size() && text[i] != '>')
			{ i++; }
			int count = i-start;

			return text.substr(start, count);
		}

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

		void tree2doc_re(Node* node, int level)
		{
			for(int i = 0; i < level; i++)
			{ text += '\t'; }
			if(!node->terminal)
			{
				text += "<" + node->data + ">\n";
				for(int i = 0; i < node->children.size(); i++)
				{ tree2doc_re(node->children[i], level+1); }
				for(int i = 0; i < level; i++)
				{ text += '\t'; }
				text += "</" + node->data + ">\n";
			}
			else
			{ text += node->data + "\n"; }
		}

	public:
		int count()
		{
			int tags = 0;
			for(int i = 0; i < text.size(); i++)
			{ if(is_tag(i)){ tags++; } }
			return tags;
		}

		bool validate()
		{
			std::vector<std::string> stack = std::vector<std::string>();
			
			for(int i = 0; i < text.size(); i++)
			{
				if(is_tag(i))
				{
					std::string tag = read_tag(i);
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

		std::vector<std::string> tokenize()
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
		
		Node* parse()
		{
			std::vector<std::string> tokens = tokenize();
			std::vector<Node*> tree = std::vector<Node*>();
			Node* root = nullptr;
			
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
							root = tree.back();
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
			
			return root;
		}

		void write(std::string path)
		{
			std::ofstream file = std::ofstream(path);
			file << text;
			file.close();
		}

		Doc(std::string path)
		{
			std::ifstream file = std::ifstream(path);
			std::stringstream buffer;
			buffer << file.rdbuf();
			text = buffer.str();
			file.close();
		}
		Doc(Node* tree)
		{ tree2doc_re(tree, 0); }
};

