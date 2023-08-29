// Read online: https://github.com/ocornut/imgui/tree/master/docs

#include <stdio.h>
#include <iostream>
#include <filesystem>
#include <fstream>
#include <map>

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

#include "tree.h"
#include "doc.h"

namespace fsys = std::filesystem;

struct Asset
{
	std::string path;
	Doc doc;
	Node* tree;
};

struct Globals
{
	std::vector<std::string> traits;
};
Globals globals;

static void glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "<!> [GLFW] %d: %s\n", error, description);
}

Globals load_globals(fsys::path path)
{
	fsys::path traits_path = path/"traits.csv";
	if(!fsys::exists(traits_path))
	{
		std::ofstream file = std::ofstream(traits_path);
		file.close();
	}

	std::ifstream file = std::ifstream(traits_path);
	std::stringstream traits_buffer;
	traits_buffer << file.rdbuf();
	std::string traits_text = traits_buffer.str();
	file.close();

	std::vector<std::string> traits = std::vector<std::string>();
	int trait_start = 0;
	for(int i = 0; i < traits_text.size(); i++)
	{
		if(traits_text[i] == ',' || traits_text[i] == '\n')
		{
			traits.push_back(traits_text.substr(trait_start, i));
			trait_start = i+1;
		}
	}

	return {traits};
}

void draw_file_adder(fsys::path path)
{
	static std::string add_name = "";
	ImGui::InputText(path.c_str(), &add_name);
	fsys::path add_path = path/add_name;

	if(add_name.length() >= 3 || !fsys::exists(add_path))
	{
		if(ImGui::Button("Add##add_file_button"))
		{
			std::ofstream file = std::ofstream(add_path);
			file.close();
		}
	}
	else
	{ ImGui::Text("Directory empty. Enter a valid file name to begin"); }
}

void draw_file_loader(fsys::path path, Asset& asset)
{
	static int select_idx = 0;

	std::vector<fsys::path> entries = std::vector<fsys::path>();
	for(fsys::path entry : fsys::directory_iterator(path))
	{
		if(fsys::is_regular_file(entry))
		{ entries.push_back(entry); }
	}

	if(ImGui::BeginListBox(path.c_str()))
	{
		for(int i = 0; i < entries.size(); i++)
		{
			if(ImGui::Selectable(entries[i].c_str(), i == select_idx))
			{ select_idx = i; }
		}
		ImGui::EndListBox();
	}
	std::string selection = entries[select_idx];

	if(ImGui::Button("Load##load_tree_button"))
	{
		Doc doc = Doc(selection);
		if(!doc.validate())
		{
			ImGui::OpenPopup("Error##invalid_doc_popup");
			if(ImGui::BeginPopupModal("Error##invalid_doc_popup"))
			{
				ImGui::Text("Document does not contain valid XML");
				ImGui::EndPopup();
			}
		}
		else
		{
			Node* tree = doc.parse();
			if(tree == nullptr)
			{ tree = new Node("root", false); }
			asset = {selection, doc, tree};
		}
	}
}

void draw_driver_editor(Node* node, int level)
{
	if(level == 0)
	{
		ImGui::PushID(node);
		if(ImGui::TreeNode(node->data.c_str()))
		{	
			for(int i = 0; i < node->children.size(); i++)
			{ draw_driver_editor(node->children[i], level+1); }
			
			if(ImGui::Button("Add Weight"))
			{
				Node* trait_node = new Node(globals.traits[0], false);
				Node* weight_node = new Node("0", true);
				trait_node->children.push_back(weight_node);
				node->children.push_back(trait_node);
			}
			ImGui::TreePop();
		}
		ImGui::PopID();
	}
	else
	{
		ImGui::PushID(node);
		if(ImGui::BeginCombo("##driver_trait_input", node->data.c_str()))
		{
			for(std::string trait : globals.traits)
			{
				if(ImGui::Selectable(trait.c_str(), trait == node->data))
				{ node->data = trait; }
			}
			ImGui::EndCombo();
		}
		ImGui::SameLine();
		ImGui::InputText("##driver_weight_input", &node->children.back()->data);
		ImGui::PopID();
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

	std::string sections[] = {"drivers", "items", "demographics", "packs", "globals"};
	for(std::string section : sections)
	{
		fsys::path section_path = workspace_path/section;
		if(!fsys::exists(section_path) || !fsys::is_directory(section_path))
		{
			std::cerr <<"error: workspace does not have requisite sections" << std::endl;
			return 1;
		}
	}

	int tab_idx = 0;
	Asset default_asset = {"", Doc(""), nullptr}; 
	Asset assets[] = {default_asset, default_asset, default_asset, default_asset, default_asset};
	globals = load_globals(workspace_path/"globals");

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
    GLFWwindow* window = glfwCreateWindow(1280, 720, "Trendsetter", nullptr, nullptr);
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

			// Compose test window
            ImGui::Begin(workspace_pathname.c_str(), nullptr, flags);
			if(ImGui::BeginTabBar("Workspace Tabs", ImGuiTabBarFlags_None))
			{
				int idx = 0;
				for(std::string section : sections)
				{
					if(ImGui::BeginTabItem(section.c_str()))
					{
						tab_idx = idx;
						ImGui::EndTabItem();
					}
					idx++;
				}
				ImGui::EndTabBar();
			}
			fsys::path section_path = workspace_path/sections[tab_idx];

			if(assets[tab_idx].tree == nullptr)
			{
				size_t n_files = 0;
				for(fsys::path entry : fsys::directory_iterator(section_path))
				{
					if(fsys::is_regular_file(entry))
					{ n_files++; }
				}

				if(n_files > 0)
				{ draw_file_loader(section_path, assets[tab_idx]); }
				else
				{ draw_file_adder(section_path); }
			}
			else
			{ 
				ImGui::Text(assets[tab_idx].path.c_str());
				ImGui::SameLine();
				if(ImGui::Button("Save##asset_save_button"))
				{
					Doc doc = Doc(assets[tab_idx].tree);
					doc.write(assets[tab_idx].path);
				}
				ImGui::Separator();

				if(sections[tab_idx] == "drivers")
				{ draw_driver_editor(assets[tab_idx].tree, 0); }
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

	for(Asset asset : assets)
	{
		if(asset.tree != nullptr)
		{ delete asset.tree; }
	}

    ImGui_ImplMetal_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}
