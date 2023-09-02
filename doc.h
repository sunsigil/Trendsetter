#include <string>
#include <vector>
#include "node.h"

class Doc
{
	protected:
		std::string text;
		std::vector<std::string> tokens;

		virtual std::string read(std::string path);
		virtual std::string read(Node* graph);
		virtual std::vector<std::string> lex(std::string text);

	public:
		virtual bool validate();
		virtual Node* graph();
		virtual void write(std::string path);
		virtual std::string dump();
		
		Doc();
		Doc(std::string path);
		Doc(Node* graph);
};

class XMLDoc : public Doc
{
	protected:
		virtual std::string read(Node* graph);
		virtual std::vector<std::string> lex(std::string text);

	public:
		virtual bool validate();
		virtual Node* graph();

		XMLDoc(std::string path);
		XMLDoc(Node* graph);
};

class CSVDoc : public Doc
{
	protected:
		virtual std::string read(Node* graph);
		virtual std::vector<std::string> lex(std::string text);

	public:
		virtual Node* graph();

		CSVDoc(std::string path);
		CSVDoc(Node* graph);
};

