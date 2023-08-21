// Read online: https://github.com/ocornut/imgui/tree/master/docs

#include <stdio.h>
#include <iostream>

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

static void glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "<!> [GLFW] %d: %s\n", error, description);
}

std::string node_popup_data;
void draw_node_popup(Node* node, bool terminal)
{
	ImGui::InputText("Data", &node_popup_data);

	if(ImGui::Button("Confirm"))
	{
		Node* add = new Node(node_popup_data, terminal);
		std::cerr << &node_popup_data << " " << terminal << " " << &(add->data) << std::endl;
		node->children.push_back(add);
		ImGui::CloseCurrentPopup();
	}

	ImGui::SameLine();
	if(ImGui::Button("Cancel"))
	{ ImGui::CloseCurrentPopup(); }
}

void draw_tree(Node* node)
{
	if(!node->terminal)
	{	
		ImGui::PushID(node);
		if(ImGui::TreeNode(node->data.c_str()))
		{	
			for(int i = 0; i < node->children.size(); i++)
			{ draw_tree(node->children[i]); }
			
			if(ImGui::Button("Add Node"))
			{ ImGui::OpenPopup("Add Node"); }
			if(ImGui::BeginPopupModal("Add Node"))
			{
				draw_node_popup(node, false);
				ImGui::EndPopup();
			}

			if
			(
				node->children.size() == 0 ||
				!node->children.back()->terminal
			)
			{
				if(ImGui::Button("Add Content"))
				{ ImGui::OpenPopup("Add Content"); }
				if(ImGui::BeginPopupModal("Add Content"))
				{
					draw_node_popup(node, true);
					ImGui::EndPopup();
				}
			}

			ImGui::TreePop();
		}
		ImGui::PopID();
	}
	else
	{
		ImGui::PushID(node);
		ImGui::InputText("Content", &node->data);
		ImGui::PopID();
	}
}

int main(int argc, char** argv)
{
	if(argc < 2)
	{
		std::cerr << "usage: edit <DOCUMENT>" << std::endl;
		return 1;
	}
	std::string path = argv[1];

	Doc rd_doc = Doc(path);
	if(!rd_doc.validate())
	{
		std::cerr << "error: document does not contain valid XML" << std::endl;
		return 1;
	}
	Node* tree = rd_doc.parse();

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

    // Load Fonts
    // - If no fonts are loaded, dear imgui will use the default font. You can also load multiple fonts and use ImGui::PushFont()/PopFont() to select them.
    // - AddFontFromFileTTF() will return the ImFont* so you can store it if you need to select the font among multiple.
    // - If the file cannot be loaded, the function will return a nullptr. Please handle those errors in your application (e.g. use an assertion, or display an error and quit).
    // - The fonts will be rasterized at a given size (w/ oversampling) and stored into a texture when calling ImFontAtlas::Build()/GetTexDataAsXXXX(), which ImGui_ImplXXXX_NewFrame below will call.
    // - Use '#define IMGUI_ENABLE_FREETYPE' in your imconfig file to use Freetype for higher quality font rendering.
    // - Read 'docs/FONTS.md' for more instructions and details.
    // - Remember that in C/C++ if you want to include a backslash \ in a string literal you need to write a double backslash \\ !
    //io.Fonts->AddFontDefault();
    //io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\segoeui.ttf", 18.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/DroidSans.ttf", 16.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/Roboto-Medium.ttf", 16.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/Cousine-Regular.ttf", 15.0f);
    //ImFont* font = io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\ArialUni.ttf", 18.0f, nullptr, io.Fonts->GetGlyphRangesJapanese());
    //IM_ASSERT(font != nullptr);

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
            ImGui::Begin(path.c_str(), nullptr, flags);
			draw_tree(tree);
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

    // Cleanup
	Doc wr_doc = Doc(tree);
	wr_doc.write(path);
	delete tree;

    ImGui_ImplMetal_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}
