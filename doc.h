#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <iostream>

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
			int start = token.find_first_not_of(" \t\n\0");
			int end = token.find_last_not_of(" \t\n");
			if(start == -1 || end == -1)
			{ return ""; }
			return token.substr(start, end-start+1);
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
			
			int tag_count = count();
			int tag_idx = 0;
			int i = 0;

			while(i < text.size() && tag_idx < tag_count)
			{
				if(is_tag(i))
				{
					std::string tag = clean_token(read_tag(i));
					if(tag[0] == '/')
					{ tokens.push_back("e:"+tag.substr(1, tag.size()-1)); }
					else
					{ tokens.push_back("s:"+tag); } 

					tag_idx += 1;
					i += tag.size()+2;
				}
				else
				{
					std::string content = "";
					while(!is_tag(i))
					{
						content += text[i];
						i += 1;
					}
					content = clean_token(content);

					if(content.size() > 0)
					{ tokens.push_back("c:"+content); }
				}
			}

			return tokens;
		}

		Node* sprout()
		{
			std::vector<std::string> tokens = tokenize();
			std::vector<Node*> tree = std::vector<Node*>();

			for(int i = 0; i < tokens.size(); i++)
			{
				std::string token = tokens[i];
				std::string payload = token.substr(2, token.size()-2);
				Node* node;

				switch(token[0])
				{
					case 's':
						node = new Node(payload);
						if(tree.size() > 0)
						{ tree.back()->add_child(node); }
						tree.push_back(node);
					break;
					case 'e':
						tree.pop_back();
					break;
					case 'c':
						node = new Node(payload);
						tree.back()->add_child(node);
					break;
				}
			}
			
			return tree.front();
		}

		Doc(std::string path)
		{
			std::ifstream file = std::ifstream(path);
			std::stringstream buffer;
			buffer << file.rdbuf();
			text = buffer.str();
			file.close();
		}
};

