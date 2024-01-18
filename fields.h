#pragma once

#include <string>
#include <vector>

#include "imgui.h"
#include "misc/cpp/imgui_stdlib.h"

#include "node.h"

namespace fsys = std::filesystem;

Node* add_field(Node* node, std::string name, std::string data)
{
	Node* field = new Node(name, data);
	node->children.push_back(field);
	return field;
}

Node* enforce_field(Node* node, std::string name, std::string data)
{
	Node* candidate = node_lookup(node, name);
	if(candidate != nullptr)
	{ return candidate; }
	return add_field(node, name, data);
}

bool del_field(Node* parent, Node* field)
{
	for(int i = 0; i < parent->children.size(); i++)
	{
		if(parent->children[i] == field)
		{
			delete field;
			parent->children.erase(parent->children.begin() + i);
			return true;
		}
	}
	return false;
}

void draw_text_field(Node* node, std::string label, ImGuiInputTextFlags flags = 0)
{
	ImGui::PushID(node);
	ImGui::InputText(label.c_str(), &node->data);
	ImGui::PopID();
}

void draw_block_field(Node* node, std::string label)
{
	ImGui::PushID(node);
	ImGui::InputTextMultiline
	(
		label.c_str(),
		&node->data,
		ImVec2(0,0),
		ImGuiInputTextFlags_CtrlEnterForNewLine,
		nullptr,
		nullptr
	);
	ImGui::PopID();
}

void draw_int_field(Node* node, int min, int max, std::string label)
{
	ImGui::PushID(node);
	int value = std::stoi(node->data);
	ImGui::SliderInt(label.c_str(), &value, min, max);
	node->data = std::to_string(value);
	ImGui::PopID();
}

void draw_combo_field(Node* node, std::vector<std::string> options, std::string label)
{
	ImGui::PushID(node);
	if(ImGui::BeginCombo(label.c_str(), node->data.c_str()))
	{
		for(std::string option : options)
		{
			if(ImGui::Selectable(option.c_str(), option == node->data))
			{ node->data = option; }
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
	std::sort(entries.begin(), entries.end());

	if(ImGui::BeginCombo(label.c_str(), node->data.c_str()))
	{
		for(fsys::path entry : entries)
		{
			if(ImGui::Selectable(entry.filename().c_str(), entry.filename() == node->data))
			{ node->data = entry.filename(); }
		}
		ImGui::EndCombo();
	}
	ImGui::PopID();
}

void draw_combo_field_str(std::string& str, std::vector<std::string> options, std::string label)
{
	ImGui::PushID(&str);
	if(ImGui::BeginCombo(label.c_str(), str.c_str()))
	{
		for(std::string option : options)
		{
			if(ImGui::Selectable(option.c_str(), option == str))
			{ str = option; }
		}
		ImGui::EndCombo();
	}
	ImGui::PopID();
}

void draw_int_field_str(std::string& str, int min, int max, std::string label)
{
	ImGui::PushID(&str);
	int value = std::stoi(str);
	ImGui::SliderInt(label.c_str(), &value, min, max);
	str = std::to_string(value);
	ImGui::PopID();
}


