#pragma once

#include <string>
#include <vector>
#include <filesystem>
#include <iostream>

#include "imgui.h"
#include "misc/cpp/imgui_stdlib.h"

#include "node.h"
#include "doc.h"

namespace fsys = std::filesystem;

void draw_list_select_form(std::vector<std::string> items, int& selection, std::string label)
{
	if(ImGui::BeginListBox(label.c_str()))
	{
		for(int i = 0; i < items.size(); i++)
		{
			if
			(
				ImGui::Selectable
				(
					items[i].c_str(),
					i == selection,
					ImGuiSelectableFlags_AllowDoubleClick
				) &&
				ImGui::IsMouseDoubleClicked(0)
			)
			{ selection = i; }
		}
		ImGui::EndListBox();
	}
}

void draw_list_edit_form(std::vector<std::string>& items, std::string& addition, ImGuiInputTextFlags flags)
{
	ImGui::PushID(&addition);
	for(int i = 0; i < items.size(); i++)
	{
		ImGui::PushID(i);
		ImGui::InputText("##item_edit", &items[i], flags);
		ImGui::SameLine();
		if(ImGui::Button("Delete"))
		{
			items.erase(items.begin()+i);
			i--;
		}
		ImGui::PopID();
	}
	ImGui::InputText("##item_add", &addition, flags);
	ImGui::SameLine();
	if(ImGui::Button("Add") && addition.size() > 0)
	{
		items.push_back(addition);
		addition = "";
	}
	ImGui::PopID();
}

void draw_file_adder(fsys::path path)
{
	static std::string add_name = "";
	ImGui::InputText("##file_adder_input", &add_name);
	fsys::path add_path = path/add_name;

	ImGui::SameLine();
	if(add_name.length() == 0)
	{ ImGui::Text("Enter name to create new file!"); }
	else if(add_path.extension() != ".xml")
	{ ImGui::Text("File must be of type .XML!"); }
	else if(fsys::exists(add_path))
	{ ImGui::Text("File name belongs to existing file!"); }
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

void draw_file_selector(fsys::path dir, fsys::path& path_result, Node*& graph_result)
{
	static int selection = -1;
	
	std::vector<std::string> entries = std::vector<std::string>();
	for(fsys::path candidate : fsys::directory_iterator(dir))
	{
		if(fsys::is_regular_file(candidate) && candidate.extension() == ".xml")
		{ entries.push_back(candidate); }
	}

	draw_list_select_form(entries, selection, dir);
	
	if(selection != -1)
	{
		path_result = entries[selection];

		XMLDoc doc = XMLDoc(path_result);
		if(doc.validate())
		{
			graph_result = doc.graph();
			if(graph_result == nullptr)
			{ graph_result = new Node("root", ""); }
			selection = -1;
		}
		else
		{ ImGui::OpenPopup("Error##invalid_doc_popup"); }

		if(ImGui::BeginPopupModal("Error##invalid_doc_popup"))
		{
			ImGui::Text("Document's contents are invalid!");
			if(ImGui::Button("Close##close_invalid_doc_popup"))
			{
				ImGui::CloseCurrentPopup();
				selection = -1;
			}
			ImGui::EndPopup();
		}
	}
}
