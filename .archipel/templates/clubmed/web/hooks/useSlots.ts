import { Children, isValidElement, ReactNode } from "react"

/**
 * Distribue les children dans des slots nommés via la prop `data-slot`.
 * Les enfants sans data-slot sont collectés dans slots["children"].
 * Corrige le bug du registry Trident qui liste ce hook comme dépendance npm.
 */
export function useSlots(
  children: ReactNode,
  slotNames: string[]
): Record<string, ReactNode> {
  const slots: Record<string, ReactNode> = {}
  const defaultChildren: ReactNode[] = []

  Children.forEach(children, (child) => {
    if (!isValidElement(child)) {
      defaultChildren.push(child)
      return
    }
    const slot = (child.props as { "data-slot"?: string })["data-slot"]
    if (slot && slotNames.includes(slot)) {
      slots[slot] = child
    } else {
      defaultChildren.push(child)
    }
  })

  if (defaultChildren.length > 0) {
    slots["children"] = defaultChildren.length === 1
      ? defaultChildren[0]
      : defaultChildren
  }

  return slots
}
