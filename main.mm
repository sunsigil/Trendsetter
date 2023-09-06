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

bool is_enum_str(std::string str)
{
	if(str.length() == 0)
	{ return false; }
	if(str[0] == '_')
	{ return false; }

	for(int i = 0; i < str.length(); i++)
	{
		if(str[i] != '_' && (!isalnum(str[i]) || !isupper(str[i])))
		{ return false; }
	}

	return true;
}

void draw_file_selector(fsys::path section, fsys::path& path, Node*& graph)
{
	std::vector<fsys::path> entries = std::vector<fsys::path>();
	for(fsys::path entry : fsys::directory_iterator(section))
	{
		if(fsys::is_regular_file(entry))
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
	else if(!add_path.extension().empty() && fsys::exists(add_path))
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

void draw_driver_editor(Node* node, Node* traits, int level)
{
	if(level == 0)
	{
		for(int i = 0; i < node->children.size(); i++)
		{ draw_driver_editor(node->children[i], traits, level+1); }
		
		if(ImGui::Button("Add Weight"))
		{
			Node* trait_node = new Node(traits->data, false);
			Node* weight_node = new Node("0", true);
			trait_node->children.push_back(weight_node);
			node->children.push_back(trait_node);
		}
	}
	else
	{
		ImGui::PushID(node);
		ImGui::PushItemWidth(WIDTH/6);
		if(ImGui::BeginCombo("##driver_trait_input", node->data.c_str()))
		{
			Node* ptr = traits;
			while(ptr != nullptr)
			{
				std::string trait = ptr->data;
				if(ImGui::Selectable(trait.c_str(), trait == node->data))
				{ node->data = trait; }
				ptr = ptr->terminal ? nullptr : ptr->children.back();
			}
			ImGui::EndCombo();
		}
		ImGui::SameLine();
		ImGui::InputText("##driver_weight_input", &node->children.back()->data);
		ImGui::PopItemWidth();
		ImGui::PopID();
	}
}

void draw_global_editor(Node* node)
{
	Node* ptr = node;
	Node* last = nullptr;
	while(ptr != nullptr)
	{
		ImGui::PushID(ptr);
		std::string old_data = ptr->data;
		ImGui::InputText("##trait_name_input", &ptr->data);
		if(!is_enum_str(ptr->data))
		{ ptr->data = old_data; }
		ImGui::PopID();

		last = ptr;
		ptr = ptr->terminal ? nullptr : ptr->children.back();
	}

	static std::string add_name = "";
	ImGui::PushItemWidth(WIDTH/6);
	ImGui::InputText("##trait_add_input", &add_name);
	if(is_enum_str(add_name))
	{
		ImGui::SameLine();
		if(ImGui::Button("Add"))
		{
			last->terminal = false;
			Node* child = new Node(add_name, true);
			last->children.push_back(child);
			add_name = "";
		}
	}
	else
	{
		ImGui::SameLine();
		ImGui::Text("Trait names must be formatted LIKE_SO.");
	}
	ImGui::PopItemWidth();
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

	std::string sections[] = {"drivers", "items", "demographics", "agendas", "packs", "globals"};
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
	fsys::path paths[] = {"", "", "", "", "", ""};
	Node* graphs[] = {nullptr, nullptr, nullptr, nullptr, nullptr, nullptr};

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
			ImGui::SetNextWindowSize(ImVec2(width, height));
            ImGui::Begin(workspace_pathname.c_str(), nullptr, flags);

			// Draw tab bar, identify section path and index
			if(ImGui::BeginTabBar("Workspace Tabs", ImGuiTabBarFlags_None))
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
						draw_driver_editor(graphs[section_idx], graphs[5], 0);
					}
					else if(sections[section_idx] == "globals")
					{
						draw_global_editor(graphs[section_idx]);
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
