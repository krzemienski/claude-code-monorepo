import ProjectDescription

let config = Config(
    compatibleXcodeVersions: .all,
    cloud: nil,
    swiftVersion: "5.10",
    plugins: [],
    generationOptions: .options(
        resolveDependenciesWithSystemScm: false,
        disablePackageVersionLocking: false
    )
)