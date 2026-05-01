import { Application } from "@hotwired/stimulus"

import ThemeController from "./theme_controller"
import DropdownController from "./dropdown_controller"
import ClipboardController from "./clipboard_controller"
import FlashController from "./flash_controller"
import ChatController from "./chat_controller"

const application = Application.start()

application.register("theme", ThemeController)
application.register("dropdown", DropdownController)
application.register("clipboard", ClipboardController)
application.register("flash", FlashController)
application.register("chat", ChatController)

window.Stimulus = application
