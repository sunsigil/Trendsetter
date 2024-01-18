#include <stdio.h>
#include <iostream>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <map>

#define GLFW_INCLUDE_NONE
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GL/glew.h> 
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#include "imgui.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"
#include "misc/cpp/imgui_stdlib.h"

#include "node.h"
#include "doc.h"
#include "image.h"
#include "fields.h"
#include "forms.h"

#define WIDTH 1280
#define HEIGHT 720
namespace fsys = std::filesystem;

static void glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "<!> [GLFW] %d: %s\n", error, description);
}

void eprint(std::string msg)
{ std::cerr << msg << std::endl; }

void eprintv(std::vector<std::string> msgs)
{
	for(int i = 0; i < msgs.size(); i++)
	{ std::cerr << msgs[i] << std::endl; }
}

void draw_driver_editor(Node* node, Node* globals, fsys::path workspace_path)
{
	Node* types_node = node_lookup(globals, "types");
	std::vector<std::string> types = node_flatten(types_node);
	Node* traits_node = node_lookup(globals, "traits");
	std::vector<std::string> traits = node_flatten(traits_node);

	if(node->name == "root")
	{
		if(node->children.size() == 0)
		{
			add_field(node, "name", "NONE");
			add_field(node, "icon", "NONE");
			add_field(node, "description", "NONE");
			add_field(node, "hint", "NONE");
			add_field(node, "weights", "");
		}
		for(Node* child : node->children)
		{ draw_driver_editor(child, globals, workspace_path); }
	}
	else if(node->name == "icon")
	{
		draw_asset_field(node, workspace_path/"icons", ".png", "icon");
	}
	else if(node->name == "description")
	{
		draw_block_field(node, node->name);
	}
	else if(node->name == "hint")
	{
		draw_text_field(node, node->name);
	}
	else if(node->name == "weights")
	{
		ImGui::SeparatorText("Weights");
		ImGui::PushID(node);

		ImGui::PushItemWidth(WIDTH/5);
		for(Node* child : node->children)
		{
			ImGui::PushID(child);
			Node* key = child->children[0];
			Node* value = child->children[1];
			draw_combo_field(key, traits, "key");
			ImGui::SameLine();
			draw_int_field(value, -3, 3, "value");
			ImGui::SameLine();
			if(ImGui::Button("Delete"))
			{ del_field(node, child); }
			ImGui::PopID();
		}
		ImGui::PopItemWidth();

		if(ImGui::Button("Add Weight"))
		{
			Node* pair = add_field(node, "weight", "");
			add_field(pair, "key", "NONE");
			add_field(pair, "value", "0");
		}
		ImGui::PopID();
	}
	else
	{
		draw_text_field(node, node->name);
	}
}

void draw_item_editor(Node* node, Node* globals, std::map<std::string, image_t>& icon_table, fsys::path workspace_path)
{
	Node* types_node = node_lookup(globals, "types");
	std::vector<std::string> types = node_flatten(types_node);
	Node* traits_node = node_lookup(globals, "traits");
	std::vector<std::string> traits = node_flatten(traits_node);

	if(node->name == "root")
	{
		if(node->children.size() == 0)
		{
			add_field(node, "name", "NONE");
			add_field(node, "icon", "NONE");
			add_field(node, "type", "NONE");
			add_field(node, "traits", "");
		}
		for(Node* child : node->children)
		{ draw_item_editor(child, globals, icon_table, workspace_path); }
	}
	else if(node->name == "icon")
	{
		if(icon_table.find(node->data) != icon_table.end())
		{
			draw_image(icon_table[node->data]);
			ImGui::SameLine();
		}
		draw_asset_field(node, workspace_path/"icons", ".png", "icon");
	}
	else if(node->name == "type")
	{
		draw_combo_field(node, types, "type"); 
	}
	else if(node->name == "traits")
	{
		ImGui::PushID(node);
		ImGui::Text(node->name.c_str());
		ImGui::Separator();

		for(Node* child : node->children)
		{
			ImGui::PushID(child);
			draw_combo_field(child, traits, "##trait");
			ImGui::SameLine();
			if(ImGui::Button("Delete"))
			{ del_field(node, child); }
			ImGui::PopID();
		}

		if(ImGui::Button("Add Trait"))
		{ add_field(node, "trait", traits[0]); }
		ImGui::PopID();
	}
	else
	{
		draw_text_field(node, node->name);
	}
}

void draw_demographic_editor(Node* node, Node* globals)
{
	Node* traits_node = node_lookup(globals, "traits");
	std::vector<std::string> traits = node_flatten(traits_node);

	if(node->name == "root")
	{
		if(node->children.size() == 0)
		{
			add_field(node, "name", "NONE");
			add_field(node, "likes", "");
			add_field(node, "dislikes", "");
		}
		for(Node* child : node->children)
		{ draw_demographic_editor(child, globals); }
	}
	else if(node->name == "likes" || node->name == "dislikes")
	{	
		ImGui::PushID(node);
		ImGui::Text(node->name.c_str());
		ImGui::Separator();

		for(Node* child : node->children)
		{
			ImGui::PushID(child);
			draw_combo_field(child, traits, "##trait");
			ImGui::SameLine();
			if(ImGui::Button("Delete"))
			{ del_field(node, child); }
			ImGui::PopID();
		}

		if(ImGui::Button("Add Trait"))
		{ add_field(node, "trait", traits[0]); }
		ImGui::PopID();
	}
	else
	{ draw_text_field(node, node->name); }
}

void draw_global_editor(Node* node)
{
	static std::string traits_addition = "";
	static std::string types_addition = "";

	const ImGuiInputTextFlags enum_input_flags = 
		ImGuiInputTextFlags_CharsUppercase |
		ImGuiInputTextFlags_CharsNoBlank;

	if(node->name == "root")
	{
		if(node->children.size() == 0)
		{
			add_field(node, "traits", "");
			add_field(node, "types", "");
		}
		for(Node* child : node->children)
		{ draw_global_editor(child); }
	}
	if(node->name == "traits")
	{
		ImGui::Text("Traits");
		ImGui::Separator();
		
		std::vector<std::string> traits = node_flatten(node);
		draw_list_edit_form(traits, traits_addition, enum_input_flags);
		node_populate(node, traits);
	}
	else if(node->name == "types")
	{
		ImGui::Text("Types");
		ImGui::Separator();
		
		std::vector<std::string> types = node_flatten(node);
		draw_list_edit_form(types, types_addition, enum_input_flags);
		node_populate(node, types);
	}
}

int main(int argc, char** argv)
{
	if(argc < 2)
	{
		eprint("usage: "+std::string(argv[0])+" <WORKSPACE PATH>");
		return 1;
	}

    // Initialize GLFW
    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit())
    {
		eprint("error: failed to initialize GLFW!");
		return 1;
	}
	eprint("initialized GLFW");

    // Construct window
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "Trendsetter", nullptr, nullptr);
    if (window == nullptr)
	{ return 1; }
  	glfwMakeContextCurrent(window);
	eprint("initialized GLFW window");
  	
	// Initialize GLEW
	glewExperimental = GL_TRUE;
  	if(glewInit() != GLEW_OK)
	{
		eprint("error: failed to initialize GLEW!");
		return 1;
	}
	eprint("initialized GLEW");

	// Initialize IMGUI
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void) io;
	eprint("initialized IMGUI");
    
	// Initialize IMGUI backends
	ImGui_ImplGlfw_InitForOpenGL(window, true);
	ImGui_ImplOpenGL3_Init("#version 150");
	eprint("initialized IMGUI backends");

	// Configure IMGUI
    ImGui::StyleColorsDark();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
	const ImGuiWindowFlags flags =
	ImGuiWindowFlags_NoSavedSettings |
	ImGuiWindowFlags_NoMove |
	ImGuiWindowFlags_NoResize |
	ImGuiWindowFlags_NoSavedSettings |
	ImGuiWindowFlags_NoCollapse |
	ImGuiWindowFlags_NoTitleBar |
	ImGuiWindowFlags_NoBackground;
	eprint("configured IMGUI");
  	
	const GLubyte* renderer = glGetString(GL_RENDERER);
  	const GLubyte* version = glGetString(GL_VERSION);
  	std::cout << "Renderer: " << renderer << std::endl;
  	std::cout << "OpenGL version: " << version << std::endl;
	
	// Setup workspace
	fsys::path workspace_path = fsys::path(argv[1]);
	if(!fsys::exists(workspace_path) || !fsys::is_directory(workspace_path))
	{
		eprint("error: workspace path does not point to existing directory");
		return 1;
	}
	eprint("validated workspace path");

	std::vector<std::string> sections = {"drivers", "items", "demographics", "globals"};
	for(std::string section : sections)
	{
		fsys::path section_path = workspace_path/section;
		if(!fsys::exists(section_path) || !fsys::is_directory(section_path))
		{
			eprint("error: workspace does not have requisite sections");
			return 1;
		}
	}
	eprint("validated workspace directory structure");

	std::map<std::string, image_t> icon_table;
	for(fsys::path icon_path : fsys::directory_iterator(workspace_path/"icons"))
	{
		if(fsys::is_regular_file(icon_path) && icon_path.extension() == ".png")
		{
			image_t icon;
			load_png(icon_path, icon);
			icon_table[icon_path.filename()] = icon;
		}
	}
	std::vector<fsys::path> paths = std::vector<fsys::path>();
	std::vector<Node*> graphs = std::vector<Node*>();
	for(int i = 0; i < sections.size(); i++)
	{
		paths.push_back("");
		graphs.push_back(nullptr);
	}
	int section_idx = 0;
	eprint("initialized workspace constructs");
	
    // Main loop
    while (!glfwWindowShouldClose(window))
    {
		glfwPollEvents();
		glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);
		ImGui_ImplGlfw_NewFrame();
		ImGui_ImplOpenGL3_NewFrame();
		ImGui::NewFrame();
		
		// Anchor window
		ImGui::SetNextWindowPos(ImVec2(0, 0));
		ImGui::SetNextWindowSize(ImVec2(WIDTH, HEIGHT));
		ImGui::Begin(workspace_path.c_str(), nullptr, flags);

		// Draw tab bar, identify section path and index
		if(graphs.back() == nullptr)
		{
			ImGui::Text("A global file must be loaded before the workspace can be modified.");
			section_idx = graphs.size()-1;
		}
		else
		{
			if(ImGui::BeginTabBar("Workspace Tabs", ImGuiTabBarFlags_None))
			{
				for(int i = 0; i < sections.size(); i++)
				{
					if(ImGui::BeginTabItem(sections[i].c_str()))
					{
						section_idx = i;
						ImGui::EndTabItem();
					}
				}
				ImGui::EndTabBar();
			}
		}
		fsys::path section_path = workspace_path/sections[section_idx];

		// Load document if needed
		if(graphs[section_idx] == nullptr)
		{
			draw_file_selector(section_path, paths[section_idx], graphs[section_idx]);
			draw_file_adder(section_path);
		}
		else
		{ 
			ImGui::Text(paths[section_idx].c_str());
			ImGui::SameLine();
			if(ImGui::Button("Save##doc_write_button"))
			{
				XMLDoc doc = XMLDoc(graphs[section_idx]);
				doc.write(paths[section_idx]);
			}
			ImGui::SameLine();
			bool close = false;
			if(ImGui::Button("Close##doc_close_button"))
			{ close = true; }
			if(close)
			{ ImGui::OpenPopup("Save?##doc_save_popup"); }
			
			ImGui::Separator();

			if(sections[section_idx] == "drivers")
			{ draw_driver_editor(graphs[section_idx], graphs.back(), workspace_path); }
			else if(sections[section_idx] == "items")
			{ draw_item_editor(graphs[section_idx], graphs.back(), icon_table, workspace_path); }
			else if(sections[section_idx] == "demographics")
			{ draw_demographic_editor(graphs[section_idx], graphs.back()); }
			else if(sections[section_idx] == "globals")
			{ draw_global_editor(graphs[section_idx]); }
			
			if(ImGui::BeginPopupModal("Save?##doc_save_popup"))
			{
				ImGui::Text("Save document before closing?");
				if(ImGui::Button("Save##doc_write_button"))
				{
					XMLDoc doc = XMLDoc(graphs[section_idx]);
					doc.write(paths[section_idx]);
					graphs[section_idx] = nullptr;
					paths[section_idx] = "";
					ImGui::CloseCurrentPopup();
				}
				ImGui::SameLine();
				if(ImGui::Button("Don't Save##doc_nowrite_button"))
				{
					paths[section_idx] = "";
					graphs[section_idx] = nullptr;
					ImGui::CloseCurrentPopup();
				}
				ImGui::SameLine();
				if(ImGui::Button("Cancel##close_doc_save_popup"))
				{ ImGui::CloseCurrentPopup(); }
				ImGui::EndPopup();
			}
		}

		ImGui::End();
		ImGui::Render();
		ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
		glfwSwapBuffers(window);
    }

	for(Node* graph : graphs)
	{
		if(graph != nullptr)
		{ delete graph; }
	}
	eprint("deleted graphs");

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();
	eprint("shut down IMGUI");

    glfwDestroyWindow(window);
    glfwTerminate();
	eprint("shut down GLFW");

    return 0;
}
