import { Controller } from "@hotwired/stimulus"

/**
 * FileTree Controller - Interactive file tree navigation
 *
 * Targets:
 * - treeTarget: Container for file tree
 * - searchTarget: Search input field
 * - toggleTarget: Toggle button for sidebar
 *
 * Values:
 * - projectIdValue: Current project ID
 * - conversationIdValue: Current conversation ID
 *
 * Actions:
 * - toggleFolder: Expand/collapse folder
 * - selectFile: Select and display file content
 * - search: Filter files by name
 * - toggleSidebar: Show/hide file tree sidebar
 */
export default class extends Controller<HTMLElement> {
  static targets = [
    "tree",
    "search",
    "toggle"
  ]

  static values = {
    projectId: Number,
    conversationId: Number,
    treeData: Object
  }

  declare readonly treeTarget: HTMLElement
  declare readonly searchTarget: HTMLInputElement
  declare readonly toggleTarget: HTMLElement
  declare readonly projectIdValue: number
  declare readonly conversationIdValue: number
  declare readonly treeDataValue: any

  private expandedFolders: Set<string> = new Set()
  private selectedFile: string | null = null

  connect(): void {
    console.log("FileTree controller connected")
    
    // Load initial tree if data provided
    if (this.treeDataValue) {
      this.renderTree(this.treeDataValue)
    }
  }

  disconnect(): void {
    console.log("FileTree controller disconnected")
  }

  // Toggle folder expand/collapse
  toggleFolder(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const path = target.dataset.path

    if (!path) return

    if (this.expandedFolders.has(path)) {
      this.expandedFolders.delete(path)
      this.collapseFolder(target)
    } else {
      this.expandedFolders.add(path)
      this.expandFolder(target)
    }
  }

  // Select file and display content
  selectFile(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const path = target.dataset.path

    if (!path) return

    // Remove previous selection (querySelector targets dynamically created elements)
    // stimulus-validator: disable-next-line
    this.element.querySelectorAll('.file-item-selected').forEach(el => {
      el.classList.remove('file-item-selected')
    })

    // Mark as selected
    target.classList.add('file-item-selected')
    this.selectedFile = path

    // Find chat controller and auto-insert command
    const chatController = document.querySelector('[data-controller~="chat"]')
    if (chatController) {
      const input = chatController.querySelector('[data-chat-target="input"]') as HTMLTextAreaElement
      if (input) {
        input.value = `Read file: ${path}`
        input.focus()
      }
    }

    console.log("File selected:", path)
  }

  // Filter tree by search query
  search(event: Event): void {
    const query = this.searchTarget.value.toLowerCase()
    // stimulus-validator: disable-next-line
    const allItems = this.element.querySelectorAll('[data-file-path]')

    allItems.forEach(item => {
      const path = (item as HTMLElement).dataset.filePath || ''
      const name = path.split('/').pop() || ''
      
      if (name.toLowerCase().includes(query)) {
        (item as HTMLElement).style.display = ''
        // Show parent folders
        this.showParentFolders(item as HTMLElement)
      } else {
        (item as HTMLElement).style.display = 'none'
      }
    })
  }

  // Toggle sidebar visibility
  toggleSidebar(event: Event): void {
    event.preventDefault()
    const sidebar = this.element.closest('.file-tree-sidebar')
    sidebar?.classList.toggle('hidden')
  }

  // Render file tree structure
  private renderTree(tree: any): void {
    if (!tree || !tree.tree) return

    const html = this.renderNode(tree.tree, 0)
    this.treeTarget.innerHTML = html
  }

  // Recursively render tree node
  private renderNode(node: any, depth: number): string {
    if (!node) return ''

    const indent = `${depth * 12}px`
    
    if (node.type === 'directory') {
      const isExpanded = this.expandedFolders.has(node.path)
      const chevronIcon = isExpanded ? 'chevron-down' : 'chevron-right'
      
      const childrenHtml = isExpanded 
        ? node.children.map((child: any) => this.renderNode(child, depth + 1)).join('')
        : ''

      return `
        <div class="folder-item" data-file-path="${node.path}">
          <div 
            class="flex items-center gap-2 py-1 px-2 hover:bg-surface/50 rounded cursor-pointer text-sm"
            style="padding-left: ${indent}"
            data-action="click->file-tree#toggleFolder"
            data-path="${node.path}"
          >
            <svg class="w-4 h-4 text-secondary" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              ${chevronIcon === 'chevron-right' 
    ? '<polyline points="9 18 15 12 9 6"></polyline>' 
    : '<polyline points="6 9 12 15 18 9"></polyline>'}
            </svg>
            <svg class="w-4 h-4 text-accent" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13c0 1.1.9 2 2 2Z"/>
            </svg>
            <span class="text-primary truncate">${node.name}</span>
            <span class="text-tertiary text-xs ml-auto">${node.item_count}</span>
          </div>
          <div class="children ${isExpanded ? '' : 'hidden'}">
            ${childrenHtml}
          </div>
        </div>
      `
    } else {
      const iconHtml = this.getFileIcon(node.extension)
      const isSelected = this.selectedFile === node.path

      return `
        <div 
          class="file-item ${isSelected ? 'file-item-selected' : ''}" 
          data-file-path="${node.path}"
        >
          <div 
            class="flex items-center gap-2 py-1 px-2 hover:bg-surface/50 rounded cursor-pointer text-sm ${isSelected ? 'bg-primary/10' : ''}"
            style="padding-left: ${indent}"
            data-action="click->file-tree#selectFile"
            data-path="${node.path}"
          >
            ${iconHtml}
            <span class="text-secondary truncate">${node.name}</span>
            <span class="text-tertiary text-xs ml-auto">${this.formatFileSize(node.size)}</span>
          </div>
        </div>
      `
    }
  }

  // Expand folder
  private expandFolder(target: HTMLElement): void {
    const parent = target.closest('.folder-item')
    const children = parent?.querySelector('.children')
    
    if (children) {
      children.classList.remove('hidden')
    }

    // Update chevron icon
    const chevron = target.querySelector('svg')
    if (chevron) {
      chevron.innerHTML = '<polyline points="6 9 12 15 18 9"></polyline>'
    }
  }

  // Collapse folder
  private collapseFolder(target: HTMLElement): void {
    const parent = target.closest('.folder-item')
    const children = parent?.querySelector('.children')
    
    if (children) {
      children.classList.add('hidden')
    }

    // Update chevron icon
    const chevron = target.querySelector('svg')
    if (chevron) {
      chevron.innerHTML = '<polyline points="9 18 15 12 9 6"></polyline>'
    }
  }

  // Show parent folders for search results
  private showParentFolders(element: HTMLElement): void {
    let current = element.parentElement
    while (current && current !== this.treeTarget) {
      if (current.classList.contains('children')) {
        current.classList.remove('hidden')
      }
      current = current.parentElement
    }
  }

  // Get file icon based on extension
  private getFileIcon(extension: string): string {
    const iconColor = this.getFileIconColor(extension)
    
    // Common file type icons
    if (['.rb', '.rake'].includes(extension)) {
      return `<svg class="w-4 h-4 ${iconColor}" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m7.5 4.27 9 5.15"></path><path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"></path><path d="m3.3 7 8.7 5 8.7-5"></path><path d="M12 22V12"></path></svg>` // Ruby
    } else if (['.js', '.ts', '.jsx', '.tsx'].includes(extension)) {
      return `<svg class="w-4 h-4 ${iconColor}" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"></polyline><polyline points="8 6 2 12 8 18"></polyline></svg>` // JS/TS
    } else if (['.css', '.scss'].includes(extension)) {
      return `<svg class="w-4 h-4 ${iconColor}" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5Z"></path><path d="M4 13a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-2Z"></path></svg>` // CSS
    } else if (['.erb', '.html'].includes(extension)) {
      return `<svg class="w-4 h-4 ${iconColor}" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"></polyline><polyline points="8 6 2 12 8 18"></polyline></svg>` // HTML/ERB
    } else if (['.json', '.yml', '.yaml'].includes(extension)) {
      return `<svg class="w-4 h-4 ${iconColor}" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"></path><polyline points="14 2 14 8 20 8"></polyline></svg>` // Config
    }
    
    // Default file icon
    return `<svg class="w-4 h-4 text-tertiary" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"></path><polyline points="14 2 14 8 20 8"></polyline></svg>`
  }

  // Get color for file icon
  private getFileIconColor(extension: string): string {
    if (['.rb', '.rake'].includes(extension)) return 'text-red-500'
    if (['.js', '.jsx'].includes(extension)) return 'text-yellow-500'
    if (['.ts', '.tsx'].includes(extension)) return 'text-blue-500'
    if (['.css', '.scss'].includes(extension)) return 'text-pink-500'
    if (['.erb', '.html'].includes(extension)) return 'text-orange-500'
    if (['.json', '.yml', '.yaml'].includes(extension)) return 'text-green-500'
    return 'text-tertiary'
  }

  // Format file size
  private formatFileSize(bytes: number): string {
    if (bytes < 1024) return `${bytes}B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)}MB`
  }
}
