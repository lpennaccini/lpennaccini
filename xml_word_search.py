import os
import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext


def browse_directory(entry_dir):
    directory = filedialog.askdirectory()
    if directory:
        entry_dir.delete(0, tk.END)
        entry_dir.insert(0, directory)


def search_word(directory, word, result_widget):
    result_widget.delete(1.0, tk.END)
    if not os.path.isdir(directory):
        messagebox.showerror('Errore', 'Cartella non valida')
        return
    if not word:
        messagebox.showerror('Errore', 'Parola da cercare non specificata')
        return
    found_any = False
    for root, _, files in os.walk(directory):
        for file in files:
            if file.lower().endswith('.xml'):
                path = os.path.join(root, file)
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                    for idx, line in enumerate(lines, start=1):
                        if word in line:
                            if not found_any:
                                result_widget.insert(tk.END, f"Risultati per '{word}':\n\n")
                                found_any = True
                            result_widget.insert(tk.END, f"{path} (riga {idx}): {line.strip()}\n")
                except Exception as e:
                    result_widget.insert(tk.END, f"Errore con {path}: {e}\n")
    if not found_any:
        result_widget.insert(tk.END, f"Nessun risultato per '{word}'.")


def create_gui():
    root = tk.Tk()
    root.title('Ricerca parola in XML')

    frm_dir = tk.Frame(root)
    frm_dir.pack(padx=10, pady=5, fill='x')

    tk.Label(frm_dir, text='Cartella:').pack(side='left')
    entry_dir = tk.Entry(frm_dir, width=40)
    entry_dir.pack(side='left', padx=5)
    tk.Button(frm_dir, text='Sfoglia', command=lambda: browse_directory(entry_dir)).pack(side='left')

    frm_word = tk.Frame(root)
    frm_word.pack(padx=10, pady=5, fill='x')

    tk.Label(frm_word, text='Parola da cercare:').pack(side='left')
    entry_word = tk.Entry(frm_word, width=20)
    entry_word.pack(side='left', padx=5)

    btn_search = tk.Button(root, text='Cerca', command=lambda: search_word(entry_dir.get(), entry_word.get(), txt_result))
    btn_search.pack(pady=5)

    txt_result = scrolledtext.ScrolledText(root, width=80, height=20)
    txt_result.pack(padx=10, pady=5, fill='both', expand=True)

    root.mainloop()


if __name__ == '__main__':
    create_gui()
