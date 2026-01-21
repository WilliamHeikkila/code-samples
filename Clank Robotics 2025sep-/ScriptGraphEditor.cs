using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net.Sockets;

public partial class ScriptGraphEditor : GraphEdit
{

	public LogicGraph ScriptEditorRoot;
	private List<Node> selectedNodes = [];
	private List<Node> copyListNodes = [];
	private List<Dictionary> copyListConnections = [];

	private ulong namingIndex = 0;
	private string selectedNode = "";


	// >:(((((
	private Button notButton;
	private Button andButton;
	private Button orButton;
	private Button addButton;
	private Button subtractButton;
	private Button divideButton;
	private Button multiplyButton;
	private Button equalButton;
	private Button greaterThanButton;
	private Button lessThanButton;
	private Button constantButton;
	private Button timerButton;
	private Button moveButton;
    private Button turnButton;
	private Button moveInputButton;
	private Button turnInputButton;
	private Button inputButton;
	private Button meleeWeaponButton;
	private Button gpsButton;
	private Button vectorSplitButton;
	private Button vectorComposeButton;
	private Button vectorSubtractButton;
	private Button vectorLengthButton;
	private Button vectorNormalizeButton;
	private Button vectorDotButton;
	private Button vectorConstantButton;
	private Button vectorToForwardTurnButton;

    public override void _Ready()
	{
		base._Ready();
		ConnectionDragStarted += ConnectionStarted;
		ConnectionRequest += ConnectionFinished;
		DisconnectionRequest += Disconnect;
		DeleteNodesRequest += Delete;
		CopyNodesRequest += Copy;
		PasteNodesRequest += Paste;
		CutNodesRequest += Cut;
		NodeSelected += Select;
		NodeDeselected += DeSelect;

		// >:(((((((((((((((((((((((((((((((((((((((
		notButton = GetNode<Button>("%NotButton");
		andButton = GetNode<Button>("%AndButton");
		orButton = GetNode<Button>("%OrButton");
		addButton = GetNode<Button>("%AddButton");
		subtractButton = GetNode<Button>("%SubtractButton");
		divideButton = GetNode<Button>("%DivideButton");
		multiplyButton = GetNode<Button>("%MultiplyButton");
		equalButton = GetNode<Button>("%EqualButton");
		greaterThanButton = GetNode<Button>("%GreaterThanButton");
		lessThanButton = GetNode<Button>("%LessThanButton");
		constantButton = GetNode<Button>("%ConstantButton");
		timerButton = GetNode<Button>("%TimerButton");
		moveButton = GetNode<Button>("%MoveButton");
        turnButton = GetNode<Button>("%TurnButton");
		moveInputButton = GetNode<Button>("%MoveInputButton");
		turnInputButton = GetNode<Button>("%TurnInputButton");
		inputButton = GetNode<Button>("%InputButton");
		meleeWeaponButton = GetNode<Button>("%MeleeWeaponButton");
		gpsButton = GetNode<Button>("%GpsButton");
		vectorSplitButton = GetNode<Button>("%VectorSplitButton");
		vectorComposeButton = GetNode<Button>("%VectorComposeButton");
		vectorSubtractButton = GetNode<Button>("%VectorSubtractButton");
		vectorLengthButton = GetNode<Button>("%VectorLengthButton");
		vectorNormalizeButton = GetNode<Button>("%VectorNormalizeButton");
		vectorDotButton = GetNode<Button>("%VectorDotButton");
		vectorConstantButton = GetNode<Button>("%VectorConstantButton");
		vectorToForwardTurnButton = GetNode<Button>("%VectorToForwardTurnButton");


        notButton.Pressed += NotPressed;
		andButton.Pressed += AndPressed;
		orButton.Pressed += OrPressed;
		addButton.Pressed += AddPressed;
		subtractButton.Pressed += SubtractPressed;
		divideButton.Pressed += DividePressed;
		multiplyButton.Pressed += MultiplyPressed;
		equalButton.Pressed += EqualPressed;
		greaterThanButton.Pressed += GreaterThanPressed;
		lessThanButton.Pressed += LessThanPressed;
		constantButton.Pressed += ConstantPressed;
		timerButton.Pressed += TimerPressed;
		moveButton.Pressed += MovePressed;
		turnButton.Pressed += TurnPressed;
		moveInputButton.Pressed += MoveInputPressed;
		turnInputButton.Pressed += TurnInputPressed;
		inputButton.Pressed += InputPressed;
		meleeWeaponButton.Pressed += MeleeWeaponPressed;
		gpsButton.Pressed += GpsPressed;
		vectorSplitButton.Pressed += VectorSplitPressed;
		vectorComposeButton.Pressed += VectorComposePressed;
		vectorSubtractButton.Pressed += VectorSubtractPressed;
		vectorLengthButton.Pressed += VectorLengthPressed;
		vectorNormalizeButton.Pressed += VectorNormalizePressed;
		vectorDotButton.Pressed += VectorDotPressed;
		vectorConstantButton.Pressed += VectorConstantPressed;
		vectorToForwardTurnButton.Pressed += VectorToForwardTurnPressed;

    }
    public override void _Process(double delta)
    {
        base._Process(delta);
		
		if (Input.IsActionJustPressed("MouseLeft"))
		{
			AddNode(selectedNode, GetGlobalMousePosition(), false, false);
			selectedNode = "";
		}
	}

    private void Select(Node node) => selectedNodes.Add(node);

    private void DeSelect(Node node) => selectedNodes.Remove(node);
    private void ConnectionStarted(StringName fromNode, long fromPort, bool isOutput)
	{
		GD.Print($"Connection Started from {fromNode} to {fromPort}. output? {isOutput}");
	}
	private void ConnectionFinished(StringName fromNode, long fromPort, StringName toNode, long toPort)
	{
		ConnectNode(fromNode, (int)fromPort, toNode, (int)toPort, true);
	}

	private void Disconnect(StringName fromNode, long fromPort, StringName toNode, long toPort)
	{
		DisconnectNode(fromNode, (int)fromPort, toNode, (int)toPort);
	}

	private void Delete(Array<StringName> list)
	{
		foreach (Node child in GetChildren())
		{
			if (list.Contains(child.Name))
			{
				//Remove node and remove from selected list
                selectedNodes.Remove(child);
				child.QueueFree();

                //And connections
                foreach (Dictionary entry in Connections)
				{
					if ((StringName)entry["from_node"] == child.Name || (StringName)entry["to_node"] == child.Name)
					{
						DisconnectNode((StringName)entry["from_node"], (int)entry["from_port"], (StringName)entry["to_node"], (int)entry["to_port"]);
					}
				}
			}
		}
		
	}

	private void Copy()
	{
		//Clear previous copy list and free nodes
		foreach (Node node in copyListNodes)
		{
			node.QueueFree();
		}
		copyListNodes.Clear();

		//Duplicate selected nodes
		foreach (Node node in selectedNodes)
		{
			copyListNodes.Add(node.Duplicate());
		}

		//Also clear previous connection list and copy connections by value
		copyListConnections.Clear();

		//Build a set of node names that are being copied
		var copiedNames = new HashSet<StringName>();
		foreach (Node node in copyListNodes)
		{
			copiedNames.Add(node.Name);
		}

		//For each connection in the GraphEdit, if both endpoints are in copiedNames, create a new dictionary copy
		foreach (Dictionary entry in Connections)
		{
			var fromNode = (StringName)entry["from_node"];
			var toNode = (StringName)entry["to_node"];

			if (copiedNames.Contains(fromNode) && copiedNames.Contains(toNode))
			{
				var newEntry = new Dictionary
				{
					{"from_node", entry["from_node"]},
					{"from_port", entry["from_port"]},
					{"to_node", entry["to_node"]},
					{"to_port", entry["to_port"]},
					{"keep_alive", entry["keep_alive"]}
				};
				copyListConnections.Add(newEntry);
			}
		}
	}

	private void Paste()
	{
		//Deselect nodes
		foreach (Node node in GetChildren())
		{
			if (node is GraphElement ge) { ge.Selected = false; }
		}

		//Mapping of old name -> new name for pasted nodes
		var nameMap = new System.Collections.Generic.Dictionary<StringName, StringName>();

		//For each node stored in copyListNodes create an actual instance in the scene and assign a unique name
		foreach (Node storedNode in copyListNodes)
		{
			GraphElement dupe = (GraphElement)storedNode.Duplicate();

			//Original name from the stored duplicate (acts as the key in connection entries)
			StringName prevName = storedNode.Name;

			AddChild(dupe);

			//Assign a unique name based on namingIndex
			while (true)
			{
				bool exists = false;
				foreach (Node child in GetChildren())
				{
					if (child.Name == namingIndex.ToString()) { exists = true; break; }
				}
				if (!exists)
				{
					dupe.Name = namingIndex.ToString();
					namingIndex++;
					break;
				}
				namingIndex++;
			}

			StringName newName = dupe.Name;

			//Remember mapping from prev -> new
			nameMap[prevName] = newName;

			//Select node
			dupe.Selected = true;
			Select(dupe);
		}

		//Build new connection dictionaries using the name map
		var connectionsToAdd = new List<Dictionary>();
		foreach (Dictionary entry in copyListConnections)
		{
			var from = (StringName)entry["from_node"];
			var to = (StringName)entry["to_node"];

			//Only add connections where both endpoints have been mapped
			if (nameMap.ContainsKey(from) && nameMap.ContainsKey(to))
			{
				var newEntry = new Dictionary
				{
					{"from_node", nameMap[from]},
					{"from_port", entry["from_port"]},
					{"to_node", nameMap[to]},
					{"to_port", entry["to_port"]},
					{"keep_alive", entry["keep_alive"]}
				};
				connectionsToAdd.Add(newEntry);
			}
		}

		//Append the new connections to the GraphEdit's Connections (do not reuse original dictionaries)
		Godot.Collections.Array<Dictionary> newList = Connections;
		newList.AddRange(connectionsToAdd);
		Connections = newList;

		//Prepare copyListConnections for future pastes by creating deep copies
		var newCopyListConnections = new List<Dictionary>();
		foreach (Dictionary entry in copyListConnections)
		{
			var copied = new Dictionary
			{
				{"from_node", entry["from_node"]},
				{"from_port", entry["from_port"]},
				{"to_node", entry["to_node"]},
				{"to_port", entry["to_port"]},
				{"keep_alive", entry["keep_alive"]}
			};
			newCopyListConnections.Add(copied);
		}
		copyListConnections = newCopyListConnections;
	}

	private void Cut()
	{
		//Copy selected then delete them
		Copy();
		Godot.Collections.Array<StringName> nodeNames = [];
		foreach (Node node in selectedNodes)
		{
			nodeNames.Add(node.Name);
		}
		Delete(nodeNames);
	}

    //additionalValues legend
    //ConstNum 0 = amount
    //ConstBool 0 = state
    //Timer 0 = Loop 1 = Auto 2 = WaitTime
	//Move 0 = Speed
	//Turn 0 = Speed
	//CameraSensor 0 = BlockName 1 = Range
	//DistanceSensor 0 = BlockName 1 = Range
	//MeleeWeapon 0 = BlockName 1 = Power
	//VectorConstant 0 = X 1 = Y 2 = Z
    public ScriptNode AddNode(string type, Vector2 position, bool hasCorrectedposition, bool hasName, List<object> additionalValues = null)
	{
		ScriptNode node = null;
		if (selectedNode != "") {AudioManager.Instance.PlaySFX("place_block");}
        switch (type)
		{
			case "Add":
				node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_add.tscn").Instantiate();
                break;
            case "And":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_and.tscn").Instantiate();
                break;
            case "ConstantNumber":
                node = (ScriptConstant)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_constant.tscn").Instantiate();
                if (additionalValues == null) { break; }
				ScriptConstant sc = node as ScriptConstant;
				sc.constantType = 0;
				sc.amount = (float)additionalValues[0];
                break;
            case "ConstantBool":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_constant.tscn").Instantiate();
                if (additionalValues == null) { break; }
                ScriptConstant sc1 = node as ScriptConstant;
                sc1.constantType = 1;
				sc1.state = (bool)additionalValues[0];
                break;
            case "VectorConstant":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_constant.tscn").Instantiate();
                if (additionalValues == null) { break; }
                ScriptVectorConstant svc = node as ScriptVectorConstant;
                svc.X = (float)additionalValues[0];
                svc.Y = (float)additionalValues[1];
                svc.Z = (float)additionalValues[2];
                break;
            case "Divide":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_divide.tscn").Instantiate();
                break;
            case "Equal":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_equal.tscn").Instantiate();
                break;
            case "GreaterThan":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_greater_than.tscn").Instantiate();
                break;
            case "Input":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_input.tscn").Instantiate();
                break;
            case "Gps":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_gps.tscn").Instantiate();
                break;
            case "VectorSplit":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_split.tscn").Instantiate();
                break;
            case "VectorCompose":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_compose.tscn").Instantiate();
                break;
            case "VectorSubtract":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_subtract.tscn").Instantiate();
                break;
            case "VectorLength":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_length.tscn").Instantiate();
                break;
            case "VectorNormalize":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_normalize.tscn").Instantiate();
                break;
            case "VectorDot":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_dot.tscn").Instantiate();
                break;
            case "VectorToForwardTurn":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_to_forward_turn.tscn").Instantiate();
                break;
            ///case "VectorConstant":
               /// node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_vector_constant.tscn").Instantiate();
                ///break;
            case "Move":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_move.tscn").Instantiate();
                if (additionalValues == null) { break; }
				ScriptMove sm = node as ScriptMove;
				sm.Speed = (float)additionalValues[0];
                break;
            case "MoveInput":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_move_input.tscn").Instantiate();
                break;
			case "Turn":
				node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_turn.tscn").Instantiate();
                if (additionalValues == null) { break; }
                ScriptTurn sm1 = node as ScriptTurn;
                sm1.Speed = (float)additionalValues[0];
                break;
			case "TurnInput":
				node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_turn_input.tscn").Instantiate();
				break;
            case "LessThan":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_less_than.tscn").Instantiate();
                break;
            case "Multiply":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_multiply.tscn").Instantiate();
                break;
            case "Not":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_not.tscn").Instantiate();
                break;
            case "Or":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_or.tscn").Instantiate();
                break;
            case "Subtract":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_subtract.tscn").Instantiate();
                break;
            case "Timer":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_timer.tscn").Instantiate();
                if (additionalValues == null) { break; }
				ScriptTimer st = node as ScriptTimer;
                st.Loop = (bool)additionalValues[0];
				st.Auto = (bool)additionalValues[1];
				st.WaitTime = (float)additionalValues[2];
                break;
			case "CameraSensor":
				node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_input.tscn").Instantiate();
                if (additionalValues == null) { break; }
				ScriptInput si = node as ScriptInput;
				si.type = type;
				si.SelectedBlockName = (string)additionalValues[0];
				si.Range = (float)additionalValues[1];
                break;
            case "DistanceSensor":
                node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_input.tscn").Instantiate();
                if (additionalValues == null) { break; }
                ScriptInput si1 = node as ScriptInput;
                si1.type = type;
                si1.SelectedBlockName = (string)additionalValues[0];
				si1.Range = (float)additionalValues[1];
                break;
			case "MeleeWeapon":
				node = (ScriptNode)GD.Load<PackedScene>("res://scenes/ui/script_nodes/script_node_melee_weapon.tscn").Instantiate();
				if (additionalValues == null) { break; }
				ScriptMeleeWeapon mw = node as ScriptMeleeWeapon;
				mw.type = type;
				mw.SelectedBlockName = (string)additionalValues[0];
				mw.Power = (float)additionalValues[1];
				break;
            default:
				return null;
		}
		if (node != null){ AddChild(node); }
		if (hasCorrectedposition) { node.PositionOffset = position; }
		else
		{
			Vector2 realPosition = ((position + ScrollOffset - GlobalPosition) / Zoom);
			node.PositionOffset = realPosition;
		}

		//Assign a unique name based on namingIndex
		while (true)
		{	
			if (hasName) { break; }
			bool exists = false;
			foreach (Node child in GetChildren())
			{
				if (child.Name == namingIndex.ToString()) { exists = true; break; }
			}
			if (!exists)
			{
				node.Name = namingIndex.ToString();
				namingIndex++;
				break;
			}
			namingIndex++;
		}

		return node;
    }

	private void NotPressed()
	{
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Not";
	}
    private void AndPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
        selectedNode = "And";
    }
    private void OrPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
        selectedNode = "Or";
    }
    private void AddPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
        selectedNode = "Add";
    }
    private void SubtractPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Subtract";
    }
    private void DividePressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Divide";
    }
    private void MultiplyPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Multiply";
    }
    private void EqualPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Equal";
    }
    private void GreaterThanPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "GreaterThan";
    }
    private void LessThanPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "LessThan";
    }
    private void ConstantPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "ConstantNumber";
    }
    private void TimerPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Timer";
    }
    private void MovePressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Move";
    }
    private void TurnPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
        selectedNode = "Turn";
    }
    private void MoveInputPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "MoveInput";
    }
    private void TurnInputPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "TurnInput";
    }
	private void InputPressed()
	{
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Input";
	}
	private void MeleeWeaponPressed()
	{
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "MeleeWeapon";
	}
    private void GpsPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "Gps";
    }
    private void VectorSplitPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "VectorSplit";
    }
    private void VectorComposePressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "VectorCompose";
    }
    private void VectorSubtractPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "VectorSubtract";
    }
    private void VectorLengthPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "VectorLength";
    }
    private void VectorNormalizePressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "VectorNormalize";
    }
    private void VectorDotPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "VectorDot";
    }
    private void VectorConstantPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "VectorConstant";
    }
    private void VectorToForwardTurnPressed()
    {
		AudioManager.Instance.PlaySFX("menu_click");
		selectedNode = "VectorToForwardTurn";
    }
}
