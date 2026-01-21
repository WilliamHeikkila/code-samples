using Godot;
using System;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

public partial class EditorMenu : Control
{

	private Button saveButton;
    private Button loadButton;
	private Button testButton;
    private Button exitButton;
	private Button scriptEditorButton;

	public LineEdit RobotNameField;

    private TabContainer tabContainer;
	private LineEdit searchBox;
	private Node[] blockButtons;

	[Export]
	private String mainMenuUid;
	[Export]
	private PackedScene saveScene;
	[Export]
	private PackedScene loadScene;
	[Export]
	private PackedScene scriptEditorScene;
	[Export]
	private PackedScene testArenaScene;

	private Editor editorRootNode;

	public override void _Ready()
	{
		base._Ready();

		saveButton = GetNode<Button>("%SaveButton");
		loadButton = GetNode<Button>("%LoadButton");
		testButton = GetNode<Button>("%TestButton");
		exitButton = GetNode<Button>("%ExitButton");
		scriptEditorButton = GetNode<Button>("%ScriptEditorButton");

        editorRootNode = (Editor)GetParent();

        tabContainer = GetNode<TabContainer>("%TabContainer");
		searchBox = GetNode<LineEdit>("%SearchBox");
        RobotNameField = GetNode<LineEdit>("%RobotNameField");

		//Get all block buttons
		blockButtons = (Node[])GetTree().GetNodesInGroup("BlockButtons").ToArray();

		saveButton.Pressed += SavePressed;
		loadButton.Pressed += LoadPressed;
		testButton.Pressed += TestPressed;
		exitButton.Pressed += ExitPressed;
		scriptEditorButton.Pressed += ScriptEditorPressed;

        tabContainer.TabClicked += TabButtonPressed;
		searchBox.TextChanged += Search;
	}

	private void Search(string text)
	{
        foreach (EditorBlockButton button in blockButtons)
        {
            if (!button.blockName.ToLower().Contains(text)) button.Visible = false;
			else button.Visible = true;
        }
    }

    private void TabButtonPressed(long i)
    {
        AudioManager.Instance.PlaySFX("menu_click");
    }

	private void SavePressed()
	{
		AudioManager.Instance.PlaySFX("menu_click");
		editorRootNode.SaveRobot(RobotNameField.Text);
	}
	private void LoadPressed()
	{
		AudioManager.Instance.PlaySFX("menu_click");
		RobotLoad dialog = (RobotLoad)loadScene.Instantiate();
		AddChild(dialog);
        dialog.editorRootNode = editorRootNode;
    }

	private void TestPressed()
	{
		AudioManager.Instance.PlaySFX("menu_click");
        editorRootNode.SaveRobot(RobotNameField.Text);

		// FIND ROBOT FROM SERVER (needs to be Async)
        // Robot robot = editorRootNode.Robot;
        // await Matchmaking.Matchmake(RobotNameField.Text, robot.weightclass, robot.matchesPlayed, robot.matchesWon);

        ArenaManager scene = (ArenaManager)SceneLoader.LoadToMain(testArenaScene);
		scene.StartTest(RobotNameField.Text);
		GameState.CurrentGameState = GameState.GameStates.BATTLE;
		RemoveEditor();
    }

    private void ExitPressed()
	{
        AudioManager.Instance.PlaySFX("menu_click");
		switch (GameState.PrevGameState)
		{
			case GameState.GameStates.MAIN_MENU:
                SceneLoader.LoadToMain(GD.Load<PackedScene>(mainMenuUid));
                break;
			default:
				GD.Print("Default load to main menu");
                SceneLoader.LoadToMain(GD.Load<PackedScene>(mainMenuUid));
				break;
        }

		RemoveEditor();
    }

	private void ScriptEditorPressed()
	{
		AudioManager.Instance.PlaySFX("menu_click");
		LogicGraph scriptEditor = (LogicGraph)scriptEditorScene.Instantiate();
		AddChild(scriptEditor);
		scriptEditor.EditorRoot = (Editor)GetParent();
	}

	private void RemoveEditor() { GetParent().QueueFree(); }

}
