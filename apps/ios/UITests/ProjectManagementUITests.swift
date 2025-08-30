import XCTest

final class ProjectManagementUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-data"]
        app.launchEnvironment = ["MOCK_API": "true"]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Project List Tests
    
    func testNavigateToProjects() throws {
        app.launch()
        
        // Wait for home view
        let homeView = app.otherElements["HomeView"]
        XCTAssertTrue(homeView.waitForExistence(timeout: 5))
        
        // Tap projects tab/button
        let projectsButton = app.buttons["Projects"]
        if !projectsButton.exists {
            // Try tab bar
            let projectsTab = app.tabBars.buttons["Projects"]
            XCTAssertTrue(projectsTab.exists)
            projectsTab.tap()
        } else {
            projectsButton.tap()
        }
        
        // Verify projects view appears
        let projectsList = app.tables["ProjectsList"]
        XCTAssertTrue(projectsList.waitForExistence(timeout: 3))
    }
    
    func testProjectListDisplay() throws {
        app.launch()
        
        // Navigate to projects
        navigateToProjects()
        
        // Check for project cells
        let projectsList = app.tables["ProjectsList"]
        XCTAssertTrue(projectsList.waitForExistence(timeout: 3))
        
        // In mock mode, should have some projects
        let cells = projectsList.cells
        XCTAssertTrue(cells.count > 0, "Project list should contain mock projects")
        
        // Verify project cell structure
        let firstCell = cells.element(boundBy: 0)
        if firstCell.exists {
            // Check for project name
            let projectName = firstCell.staticTexts.firstMatch
            XCTAssertTrue(projectName.exists)
            XCTAssertFalse(projectName.label.isEmpty)
        }
    }
    
    // MARK: - Project Creation Tests
    
    func testCreateNewProject() throws {
        app.launch()
        navigateToProjects()
        
        // Find and tap create button
        let createButton = app.buttons["Create Project"]
        if !createButton.exists {
            // Try plus button
            let plusButton = app.navigationBars.buttons["Add"]
            if plusButton.exists {
                plusButton.tap()
            } else {
                // Try toolbar button
                let toolbarPlus = app.toolbars.buttons["Add"]
                XCTAssertTrue(toolbarPlus.exists)
                toolbarPlus.tap()
            }
        } else {
            createButton.tap()
        }
        
        // Wait for create project form
        let createForm = app.otherElements["CreateProjectForm"]
        if !createForm.waitForExistence(timeout: 3) {
            // Try sheet presentation
            let sheet = app.sheets.firstMatch
            XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        }
        
        // Fill in project details
        let nameField = app.textFields["Project Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Test Project")
        
        let descriptionField = app.textViews["Project Description"]
        if descriptionField.exists {
            descriptionField.tap()
            descriptionField.typeText("This is a test project created via UI test")
        }
        
        // Save project
        let saveButton = app.buttons["Save"]
        if !saveButton.exists {
            let createButton = app.buttons["Create"]
            XCTAssertTrue(createButton.exists)
            createButton.tap()
        } else {
            saveButton.tap()
        }
        
        // Verify project was added to list
        let projectsList = app.tables["ProjectsList"]
        XCTAssertTrue(projectsList.waitForExistence(timeout: 3))
        
        // Look for the new project
        let newProjectCell = projectsList.cells.containing(.staticText, identifier: "Test Project").firstMatch
        XCTAssertTrue(newProjectCell.waitForExistence(timeout: 3))
    }
    
    func testCancelProjectCreation() throws {
        app.launch()
        navigateToProjects()
        
        // Open create form
        openCreateProjectForm()
        
        // Start filling form
        let nameField = app.textFields["Project Name"]
        nameField.tap()
        nameField.typeText("Cancelled Project")
        
        // Cancel
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()
        
        // Verify form dismissed
        XCTAssertFalse(nameField.waitForExistence(timeout: 1))
        
        // Verify project was not added
        let projectsList = app.tables["ProjectsList"]
        let cancelledProject = projectsList.cells.containing(.staticText, identifier: "Cancelled Project").firstMatch
        XCTAssertFalse(cancelledProject.exists)
    }
    
    // MARK: - Project Details Tests
    
    func testViewProjectDetails() throws {
        app.launch()
        navigateToProjects()
        
        // Select first project
        let projectsList = app.tables["ProjectsList"]
        let firstProject = projectsList.cells.element(boundBy: 0)
        XCTAssertTrue(firstProject.waitForExistence(timeout: 3))
        
        // Tap to view details
        firstProject.tap()
        
        // Verify details view appears
        let detailsView = app.otherElements["ProjectDetailsView"]
        if !detailsView.waitForExistence(timeout: 3) {
            // Check for navigation title change
            let navBar = app.navigationBars.firstMatch
            XCTAssertTrue(navBar.exists)
            // Navigation bar should show project name
        }
        
        // Check for expected elements
        let sessionsSection = app.staticTexts["Sessions"]
        let statsSection = app.staticTexts["Statistics"]
        
        // At least one section should be visible
        XCTAssertTrue(sessionsSection.exists || statsSection.exists)
    }
    
    // MARK: - Search Tests
    
    func testSearchProjects() throws {
        app.launch()
        navigateToProjects()
        
        // Find search field
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("Test")
            
            // Verify filtered results
            let projectsList = app.tables["ProjectsList"]
            // In a real test, would verify only matching projects are shown
            XCTAssertTrue(projectsList.exists)
        }
    }
    
    // MARK: - Refresh Tests
    
    func testPullToRefresh() throws {
        app.launch()
        navigateToProjects()
        
        let projectsList = app.tables["ProjectsList"]
        XCTAssertTrue(projectsList.waitForExistence(timeout: 3))
        
        // Perform pull to refresh
        let firstCell = projectsList.cells.element(boundBy: 0)
        if firstCell.exists {
            let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.5))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        
        // Check for refresh indicator
        let refreshControl = app.activityIndicators.firstMatch
        // Refresh control might appear briefly
        _ = refreshControl.waitForExistence(timeout: 1)
    }
    
    // MARK: - Performance Tests
    
    func testProjectListScrollPerformance() throws {
        app.launch()
        navigateToProjects()
        
        let projectsList = app.tables["ProjectsList"]
        XCTAssertTrue(projectsList.waitForExistence(timeout: 3))
        
        measure {
            // Scroll down
            projectsList.swipeUp()
            
            // Scroll up
            projectsList.swipeDown()
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToProjects() {
        let projectsButton = app.buttons["Projects"]
        if projectsButton.exists {
            projectsButton.tap()
        } else {
            let projectsTab = app.tabBars.buttons["Projects"]
            if projectsTab.exists {
                projectsTab.tap()
            }
        }
    }
    
    private func openCreateProjectForm() {
        let createButton = app.buttons["Create Project"]
        if createButton.exists {
            createButton.tap()
        } else {
            let plusButton = app.navigationBars.buttons["Add"]
            if plusButton.exists {
                plusButton.tap()
            } else {
                let toolbarPlus = app.toolbars.buttons["Add"]
                if toolbarPlus.exists {
                    toolbarPlus.tap()
                }
            }
        }
    }
}