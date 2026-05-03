import Core

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

expect(CoreModule().name == "Core", "CoreModule should provide the default module name")

print("CoreSelfTests passed")
