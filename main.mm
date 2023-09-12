// Read online: https://github.com/ocornut/imgui/graph/master/docs

#include <stdio.h>
#include <iostream>
#include <filesystem>
#include <fstream>
#include <sstream>

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

#define GLFW_INCLUDE_NONE
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#include "imgui.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_metal.h"
#include "misc/cpp/imgui_stdlib.h"

#include "node.h"
#include "doc.h"

#define WIDTH 1280
#define HEIGHT 720
namespace fsys = std::filesystem;

static void glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "<!> [GLFW] %d: %s\n", error, description);
}

void eprint(std::string msg)
{ std::cerr << msg << std::endl; }

void add_field(Node* node, std::string field_name)
{
	Node* field_node = new Node(field_name, false);
	Node* value_node = new Node("0", true);
	field_node->children.push_back(value_node);
	node->children.push_back(field_node);
}

void add_stub(Node* node, std::string stub_name)
{
	Node* stub_node = new Node(stub_name, false);
	node->children.push_back(stub_node);
}

void del_child(Node* parent, int idx)
{
	delete parent->children[idx];
	parent->children.erase(parent->children.begin() + idx);
}

void enforce_field(Node* node, std::string field_name)
{
	for(Node* child : node->children)
	{
		if(!child->terminal && child->data == field_name)
		{ return; }
	}

	add_field(node, field_name);
}

void enforce_stub(Node* node, std::string stub_name)
{
	for(Node* child : node->children)
	{
		if(!child->terminal && child->data == stub_name)
		{ return; }
	}

	add_stub(node, stub_name);
}

void draw_text_field(Node* node, std::string label)
{
	ImGui::PushID(node);
	ImGui::InputText(label.c_str(), &node->children.back()->data);
	ImGui::PopID();
}

void draw_text_block_field(Node* node, std::string label)
{
	ImGui::PushID(node);
	ImGui::InputTextMultiline
	(
		label.c_str(),
		&node->children.back()->data,
		ImVec2(0,0),
		ImGuiInputTextFlags_CtrlEnterForNewLine,
		nullptr,
		nullptr
	);
	ImGui::PopID();
}

void draw_float_field(Node* node, float min, float max, std::string label)
{
	ImGui::PushID(node);
	float value = std::stof(node->children.back()->data);
	ImGui::SliderFloat(label.c_str(), &value, min, max);
	node->children.back()->data = std::to_string(value);
	ImGui::PopID();
}

void draw_combo_field(Node* node, Node* options, std::string label)
{
	ImGui::PushID(node);
	if(ImGui::BeginCombo(label.c_str(), node->data.c_str()))
	{
		Node* ptr = options;
		while(ptr != nullptr)
		{
			std::string option = ptr->data;
			if(ImGui::Selectable(option.c_str(), option == node->data))
			{ node->data = option; }
			ptr = ptr->terminal ? nullptr : ptr->children.back();
		}
		ImGui::EndCombo();
	}
	ImGui::PopID();
}

void draw_asset_field(Node* node, fsys::path dir, std::string ext, std::string label)
{
	ImGui::PushID(node);
	std::vector<fsys::path> entries = std::vector<fsys::path>();
	for(fsys::path entry : fsys::directory_iterator(dir))
	{
		if(fsys::is_regular_file(entry) && entry.extension() == ext)
		{ entries.push_back(entry); }
	}

	if(ImGui::BeginCombo(label.c_str(), node->children.back()->data.c_str()))
	{
		for(fsys::path entry : entries)
		{
			if(ImGui::Selectable(entry.filename().c_str(), entry.filename() == node->data))
			{ node->children.back()->data = entry.filename(); }
		}
		ImGui::EndCombo();
	}
	ImGui::PopID();
}

void draw_file_selector(fsys::path section, fsys::path& path, Node*& graph)
{
	std::vector<fsys::path> entries = std::vector<fsys::path>();
	for(fsys::path entry : fsys::directory_iterator(section))
	{
		if(fsys::is_regular_file(entry) && entry.extension() != ".meta")
		{ entries.push_back(entry); }
	}

	static int select_idx = 0;
	static bool confirmed = false;

	if(ImGui::BeginListBox(section.c_str()))
	{
		for(int i = 0; i < entries.size(); i++)
		{
			if(ImGui::Selectable(entries[i].c_str(), i == select_idx, ImGuiSelectableFlags_AllowDoubleClick))
			{
				select_idx = i;
				if(ImGui::IsMouseDoubleClicked(0))
				{ confirmed = true; }
			}
		}
		ImGui::EndListBox();
	}
	
	if(confirmed)
	{
		path = entries[select_idx];
		Doc* doc = nullptr;
		bool valid = false;

		if(path.extension() == ".xml")
		{ doc = new XMLDoc(path); }
		else if(path.extension() == ".csv")
		{ doc = new CSVDoc(path); }
		else
		{ doc = new Doc(path); }

		if(doc->validate())
		{
			graph = doc->graph();
			if(graph == nullptr)
			{ graph = new Node("root", false); }
			confirmed = false;
		}
		else
		{ ImGui::OpenPopup("Error##invalid_doc_popup"); }

		if(ImGui::BeginPopupModal("Error##invalid_doc_popup"))
		{
			ImGui::Text("Document's contents are invalid.");
			if(ImGui::Button("Close##close_invalid_doc_popup"))
			{
				confirmed = false;
				ImGui::CloseCurrentPopup();
			}
			ImGui::EndPopup();
		}

		delete doc;
	}
}

void draw_file_adder(fsys::path path)
{
	static std::string add_name = "";
	ImGui::PushItemWidth(WIDTH/4);
	ImGui::InputText("##file_adder_input", &add_name);
	ImGui::PopItemWidth();
	fsys::path add_path = path/add_name;

	ImGui::SameLine();
	if(add_name.length() == 0)
	{ ImGui::Text("Enter name to create new file."); }
	else if(add_name.length() < 3)
	{ ImGui::Text("File name is too short."); }
	else if(add_path.extension() != ".xml" && add_path.extension() != ".csv")
	{ ImGui::Text("File must be in XML or CSV format."); }
	else if(fsys::exists(add_path))
	{ ImGui::Text("File name belongs to existing file."); }
	else
	{
		if(ImGui::Button("Add##file_adder_button"))
		{
			std::ofstream file = std::ofstream(add_path);
			file.close();
			add_name = "";
			add_path = path;
		}
	}
}

void draw_driver_editor(Node* node, Node* traits, fsys::path workspace_path)
{
	if(node->data == "root")
	{
		if(node->children.size() == 0)
		{
			add_field(node, "name");
			add_field(node, "icon");
			add_field(node, "description");
			add_field(node, "hint");
			add_stub(node, "weights");
		}
		for(Node* child : node->children)
		{ draw_driver_editor(child, traits, workspace_path); }
	}
	else if(node->data == "icon")
	{
		ImGui::PushItemWidth(WIDTH/6);
		draw_asset_field(node, workspace_path/"icons", ".png", "icon");
		ImGui::PopItemWidth();
	}
	else if(node->data == "description")
	{
		ImGui::PushItemWidth(WIDTH/3);
		draw_text_block_field(node, node->data);
		ImGui::PopItemWidth();
	}
	else if(node->data == "hint")
	{
		ImGui::PushItemWidth(WIDTH/3);
		draw_text_field(node, node->data);
		ImGui::PopItemWidth();
	}
	else if(node->data == "weights")
	{
		ImGui::SeparatorText("Weights");
		ImGui::PushID(node);

		int child_idx = 0;
		for(Node* child : node->children)
		{
			ImGui::PushID(child);
			ImGui::PushItemWidth(WIDTH/6);
			draw_combo_field(child, traits, "##trait");
			ImGui::SameLine();
			draw_float_field(child, -1, 1, "##weight");
			ImGui::SameLine();
			if(ImGui::Button("Delete"))
			{ del_child(node, child_idx); }
			ImGui::PopItemWidth();
			ImGui::PopID();

			child_idx++;
		}

		if(ImGui::Button("Add Weight"))
		{ add_field(node, traits->data); }
		ImGui::PopID();
	}
	else
	{
		ImGui::PushItemWidth(WIDTH/6);
		draw_text_field(node, node->data);
		ImGui::PopItemWidth();
	}
}

void draw_item_editor(Node* node, Node* traits, fsys::path workspace_path)
{
	if(node->data == "root")
	{
		if(node->children.size() == 0)
		{
			add_field(node, "name");
			add_field(node, "icon");
			add_stub(node, "traits");
		}
		for(Node* child : node->children)
		{ draw_item_editor(child, traits, workspace_path); }
	}
	else if(node->data == "icon")
	{
		ImGui::PushItemWidth(WIDTH/6);
		draw_asset_field(node, workspace_path/"icons", ".png", "icon");
		ImGui::PopItemWidth();
	}
	else if(node->data == "traits")
	{
		ImGui::PushID(node);
		ImGui::Text(node->data.c_str());
		ImGui::Separator();

		int child_idx = 0;
		for(Node* child : node->children)
		{
			ImGui::PushID(child);
			ImGui::PushItemWidth(WIDTH/6);
			draw_combo_field(child, traits, "##trait");
			ImGui::SameLine();
			if(ImGui::Button("Delete"))
			{ del_child(node, child_idx); }
			ImGui::PopItemWidth();
			ImGui::PopID();

			child_idx++;
		}

		if(ImGui::Button("Add Trait"))
		{ add_stub(node, traits->data); }
		ImGui::PopID();
	}
	else
	{
		ImGui::PushItemWidth(WIDTH/6);
		draw_text_field(node, node->data);
		ImGui::PopItemWidth();
	}
}

void draw_demographic_editor(Node* node, Node* traits)
{
	if(node->data == "root")
	{
		if(node->children.size() == 0)
		{
			add_field(node, "name");
			add_stub(node, "likes");
			add_stub(node, "dislikes");
		}
		for(Node* child : node->children)
		{ draw_demographic_editor(child, traits); }
	}
	else if(node->data == "likes" || node->data == "dislikes")
	{	
		ImGui::PushID(node);
		ImGui::Text(node->data.c_str());
		ImGui::Separator();

		int child_idx = 0;
		for(Node* child : node->children)
		{
			ImGui::PushID(child);
			ImGui::PushItemWidth(WIDTH/6);
			draw_combo_field(child, traits, "##trait");
			ImGui::SameLine();
			if(ImGui::Button("Delete"))
			{ del_child(node, child_idx); }
			ImGui::PopItemWidth();
			ImGui::PopID();

			child_idx++;
		}

		if(ImGui::Button("Add Trait"))
		{ add_stub(node, traits->data); }
		ImGui::PopID();
	}
	else
	{
		ImGui::PushItemWidth(WIDTH/6);
		draw_text_field(node, node->data);
		ImGui::PopItemWidth();
	}
}

void draw_agenda_editor(Node* node, fsys::path workspace_path)
{
	if(node->data == "root")
	{
		if(node->children.size() == 0)
		{
			add_field(node, "demographic");
			add_stub(node, "drivers");
		}
		enforce_stub(node, "dialogue");

		for(Node* child : node->children)
		{ draw_agenda_editor(child, workspace_path); }
	}
	else if(node->data == "dialogue")
	{
		ImGui::SeparatorText("Dialogue");
		ImGui::PushID(node);
		for(Node* child : node->children)
		{ draw_text_field(child, child->data); }
		if(ImGui::Button("Add Dialogue"))
		{ add_field(node, "dialogue"); }
		ImGui::PopID();

	}
	else if(node->data == "drivers")
	{	
		ImGui::SeparatorText("Drivers");
		ImGui::PushID(node);
		ImGui::Text(node->data.c_str());
		ImGui::Separator();

		int child_idx = 0;
		for(Node* child : node->children)
		{
			ImGui::PushID(child);
			ImGui::PushItemWidth(WIDTH/6);
			draw_asset_field(child, workspace_path/"drivers", ".xml", "##driver");
			ImGui::SameLine();
			if(ImGui::Button("Delete"))
			{ del_child(node, child_idx); }
			ImGui::PopItemWidth();
			ImGui::PopID();

			child_idx++;
		}

		if(ImGui::Button("Add Driver"))
		{ add_field(node, "driver"); }
		ImGui::PopID();
	}
	else
	{
		ImGui::PushItemWidth(WIDTH/6);
		draw_asset_field(node, workspace_path/"demographics", ".xml", node->data);
		ImGui::PopItemWidth();
	}
}

void draw_global_editor(Node* node)
{
	static std::string add_name = "";
	
	ImGui::PushID(node);
	ImGui::PushItemWidth(WIDTH/6);
	ImGui::InputText
	(
		"##trait_rename_input", &node->data,
		ImGuiInputTextFlags_CharsUppercase | ImGuiInputTextFlags_CharsNoBlank
	);
	ImGui::PopItemWidth();
	ImGui::PopID();
	
	if(node->terminal)
	{
		ImGui::PushItemWidth(WIDTH/6);
		ImGui::InputText
		(
			"##trait_add_input", &add_name,
			ImGuiInputTextFlags_CharsUppercase | ImGuiInputTextFlags_CharsNoBlank
		);	
		ImGui::SameLine();
		if(ImGui::Button("Add") && add_name.size() > 0)
		{
			node->terminal = false;
			Node* child = new Node(add_name, true);
			node->children.push_back(child);
			add_name = "";
		}
		ImGui::PopItemWidth();
	}
	else
	{ draw_global_editor(node->children.back()); }
}

void draw_icon_list(fsys::path path)
{
	for(fsys::path entry : fsys::directory_iterator(path))
	{
		if(fsys::is_regular_file(entry) && entry.extension() == ".png")
		{
			ImGui::Text(entry.c_str());
		}
	}
}

int main(int argc, char** argv)
{
	if(argc < 2)
	{
		std::cerr << "usage: edit <WORKSPACE PATH>" << std::endl;
		return 1;
	}
	std::string workspace_pathname = argv[1];

	fsys::path workspace_path = fsys::path(workspace_pathname);
	if(!fsys::exists(workspace_path) || !fsys::is_directory(workspace_path))
	{
		std::cerr <<"error: workspace path does not point to existing directory" << std::endl;
		return 1;
	}

	std::string sections[] = {"drivers", "items", "demographics", "agendas", "packs", "globals", "icons"};
	for(std::string section : sections)
	{
		fsys::path section_path = workspace_path/section;
		if(!fsys::exists(section_path) || !fsys::is_directory(section_path))
		{
			std::cerr <<"error: workspace does not have requisite sections" << std::endl;
			return 1;
		}
	}

	int section_idx = 0;
	fsys::path paths[] = {"", "", "", "", "", "", ""};
	Node* graphs[] = {nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr};

    // Initialize IMGUI
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void) io;

	// Configure IMGUI
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    // io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;
	const ImGuiWindowFlags flags =
	ImGuiWindowFlags_NoMove |
	ImGuiWindowFlags_NoResize |
	ImGuiWindowFlags_NoSavedSettings |
	ImGuiWindowFlags_NoCollapse |
	ImGuiWindowFlags_NoTitleBar;

    // Initialize GLFW
    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit())
    { return 1; }

    // Construct window
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "Trendsetter", nullptr, nullptr);
    if (window == nullptr)
	{ return 1; }

	// Initialize Metal
    id <MTLDevice> device = MTLCreateSystemDefaultDevice();
    id <MTLCommandQueue> commandQueue = [device newCommandQueue];

    // Initialize backends
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplMetal_Init(device);

	// Configure Metal
    NSWindow *nswin = glfwGetCocoaWindow(window);
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    nswin.contentView.layer = layer;
    nswin.contentView.wantsLayer = YES;

    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor new];
	
    // Main loop
    while (!glfwWindowShouldClose(window))
    {
        @autoreleasepool
        {
            // Poll and handle events (inputs, window resize, etc.)
            // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
            // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
            // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
            // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
            glfwPollEvents();

            int width, height;
            glfwGetFramebufferSize(window, &width, &height);
            layer.drawableSize = CGSizeMake(width, height);
            id<CAMetalDrawable> drawable = [layer nextDrawable];

            id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
            renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
            renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
            id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
            [renderEncoder pushDebugGroup:@"Trendsetter"];

            // Start the Dear ImGui frame
            ImGui_ImplMetal_NewFrame(renderPassDescriptor);
            ImGui_ImplGlfw_NewFrame();
            ImGui::NewFrame();
            
			// Anchor window
			ImGui::SetNextWindowPos(ImVec2(0, 0));
			ImGui::SetNextWindowSize(ImVec2(WIDTH, HEIGHT));
            ImGui::Begin(workspace_pathname.c_str(), nullptr, flags);

			// Draw tab bar, identify section path and index
			if(ImGui::BeginTabBar("Workspace Tabs", ImGuiTabBarFlags_None))
			{
				if(graphs[5] == nullptr)
				{
					if(ImGui::BeginTabItem("globals"))
					{
						section_idx = 5;
						ImGui::EndTabItem();
					}
				}
				else
				{
					int idx = 0;
					for(std::string section : sections)
					{
						if(ImGui::BeginTabItem(section.c_str()))
						{
							section_idx = idx;
							ImGui::EndTabItem();
						}
						idx++;
					}
				}
				ImGui::EndTabBar();
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
					Doc* doc = nullptr;
					if(paths[section_idx].extension() == ".xml")
					{ doc = new XMLDoc(graphs[section_idx]); }
					else
					{ doc = new CSVDoc(graphs[section_idx]); }
					doc->write(paths[section_idx]);
				}
				ImGui::SameLine();
				bool close = false;
				if(ImGui::Button("Close##doc_close_button"))
				{ close = true; }
				ImGui::Separator();
				
				if(close)
				{ ImGui::OpenPopup("Save?##doc_save_popup"); }
				else
				{
					if(sections[section_idx] == "drivers")
					{
						draw_driver_editor(graphs[section_idx], graphs[5], workspace_path);
					}
					else if(sections[section_idx] == "items")
					{
						draw_item_editor(graphs[section_idx], graphs[5], workspace_path);	
					}
					else if(sections[section_idx] == "demographics")
					{
						draw_demographic_editor(graphs[section_idx], graphs[5]);
					}
					else if(sections[section_idx] == "agendas")
					{
						draw_agenda_editor(graphs[section_idx], workspace_path);
					}
					else if(sections[section_idx] == "globals")
					{
						draw_global_editor(graphs[section_idx]);
					}
					else if(sections[section_idx] == "icons")
					{
						draw_icon_list(workspace_path/"icons");
					}
				}

				if(ImGui::BeginPopupModal("Save?##doc_save_popup"))
				{
					ImGui::Text("Save document before closing?");
					if(ImGui::Button("Save##doc_write_button"))
					{
						Doc* doc = nullptr;
						if(paths[section_idx].extension() == ".xml")
						{ doc = new XMLDoc(graphs[section_idx]); }
						else if(paths[section_idx].extension() == ".csv")
						{ doc = new CSVDoc(graphs[section_idx]); }
						else
						{ doc = new Doc(graphs[section_idx]); }
						doc->write(paths[section_idx]);

						paths[section_idx] = "";
						graphs[section_idx] = nullptr;
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

            // Render
            ImGui::Render();
            ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);

            [renderEncoder popDebugGroup];
            [renderEncoder endEncoding];

            [commandBuffer presentDrawable:drawable];
            [commandBuffer commit];
        }
    }

	for(Node* graph : graphs)
	{
		if(graph != nullptr)
		{ delete graph; }
	}

    ImGui_ImplMetal_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}
