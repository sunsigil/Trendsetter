#include <string>
#include <vector>
#include "node.h"

class Doc
{
	protected:
		std::string text;
		std::vector<std::string> tokens;

		virtual std::string read(std::string path)=0;
		virtual std::string read(Node* graph)=0;
		virtual std::vector<std::string> lex(std::string text)=0;

	public:
		virtual bool validate()=0;
		virtual Node* graph()=0;
		virtual void write(std::string path)=0;
		virtual std::string dump()=0;
};

class XMLDoc : public Doc
{
	protected:
		virtual std::string read(std::string path);
		virtual std::string read(Node* graph);
		virtual std::vector<std::string> lex(std::string text);

	public:
		virtual bool validate();
		virtual Node* graph();
		virtual void write(std::string path);
		virtual std::string dump();

		XMLDoc(std::string path);
		XMLDoc(Node* graph);
};

class CSVDoc : public Doc
{
	protected:
		virtual std::string read(std::string path);
		virtual std::string read(Node* graph);
		virtual std::vector<std::string> lex(std::string text);

	public:
		virtual bool validate();
		virtual Node* graph();
		virtual void write(std::string path);
		virtual std::string dump();

		CSVDoc(std::string path);
		CSVDoc(Node* graph);
};

