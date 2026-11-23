import { createContext, useContext } from "react";

export type ToastMessage = { message: string; tone: "plain" | "success" | "error" };

export const ToastContext = createContext<(toast: ToastMessage) => void>(() => {});

export function useToast() {
  return useContext(ToastContext);
}
