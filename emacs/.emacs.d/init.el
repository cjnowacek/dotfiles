;; -------------------------------
;; Basic Emacs setup
;; -------------------------------
(setq inhibit-startup-message t)        ;; no splash screen
(menu-bar-mode -1)                      ;; hide menubar
(tool-bar-mode -1)                      ;; hide toolbar
(scroll-bar-mode -1)                    ;; hide scrollbar
(setq ring-bell-function 'ignore)       ;; no beeping

;; Better defaults
(setq make-backup-files nil             ;; no foo.txt~
      auto-save-default nil)            ;; no #foo.txt#

;; -------------------------------
;; Org mode basics
;; -------------------------------
(require 'org)

;; Pretty look
(setq org-startup-indented t        ;; virtual indent
      org-hide-emphasis-markers t   ;; hide *bold* markers
      org-startup-folded 'content   ;; start with outline folded
      org-ellipsis " ▾")            ;; nice folding symbol

(add-hook 'org-mode-hook #'visual-line-mode) ;; word wrap

;; -------------------------------
;; Org clock setup
;; -------------------------------
(setq org-clock-persist 'history)
(org-clock-persistence-insinuate)
(setq org-clock-idle-time 10
      org-clock-in-resume t)

;; -------------------------------
;; Org agenda setup
;; -------------------------------
(setq org-directory "~/org")
(setq org-agenda-files '("~/org/tasks.org" "~/org/journal.org" "~/org/timelog.org"))

(global-set-key (kbd "C-c a") 'org-agenda)  ;; open agenda
(global-set-key (kbd "C-c c") 'org-capture) ;; capture

;; Simple capture templates
(setq org-capture-templates
      `(("t" "Task" entry
         (file+headline "~/org/tasks.org" "Tasks")
         "* TODO %?\n  %U\n")
        ("j" "Journal" entry
         (file+datetree "~/org/journal.org")
         "* %U %?\n")
        ("l" "Time Log" entry
         (file+datetree "~/org/timelog.org")
         "* %U %?\n" :clock-in t :clock-keep t)))
(put 'downcase-region 'disabled nil)

;; Make sure Markdown exporter is available
(with-eval-after-load 'ox (require 'ox-md))

(defun zk/--clock-md ()
  "Return today's clocktable as Markdown (body-only)."
  (let ((org-export-use-babel nil))
    (with-temp-buffer
      (org-mode)
      (insert "* Time Tracking (today)\n"
              "#+BEGIN: clocktable :block today :link t :compact t :steps t\n"
              "#+END:\n")
      (goto-char (point-min))
      (org-update-all-dblocks)
      (require 'ox) (require 'ox-md)
      (org-export-as 'md nil nil t))))

(defun zk/--copy-to-system-clipboard (s)
  "Copy S to the OS clipboard. Return a symbol describing the method used."
  (cond
   ;; Native Windows Emacs
   ((eq system-type 'windows-nt)
    (w32-set-clipboard-data s) 'w32)

   ;; macOS GUI/terminal
   ((executable-find "pbcopy")
    (with-temp-buffer (insert s)
      (call-process-region (point-min) (point-max) "pbcopy"))
    'pbcopy)

   ;; Wayland
   ((executable-find "wl-copy")
    (with-temp-buffer (insert s)
      (call-process-region (point-min) (point-max) "wl-copy"))
    'wl-copy)

   ;; X11 (xclip/xsel)
   ((executable-find "xclip")
    (with-temp-buffer (insert s)
      (call-process-region (point-min) (point-max) "xclip" nil nil nil "-selection" "clipboard"))
    'xclip)
   ((executable-find "xsel")
    (with-temp-buffer (insert s)
      (call-process-region (point-min) (point-max) "xsel" nil nil nil "--clipboard" "--input"))
    'xsel)

   ;; WSL (clip.exe) — try PATH, then absolute fallback
   ((or (executable-find "clip.exe")
        (file-executable-p "/mnt/c/Windows/System32/clip.exe"))
    (let ((clip (or (executable-find "clip.exe")
                    "/mnt/c/Windows/System32/clip.exe")))
      (with-temp-buffer (insert s)
        (call-process-region (point-min) (point-max) clip))
      'clip.exe))

   ;; Fallback: Emacs kill-ring only
   (t (kill-new s) 'kill-ring)))

(defun zk/clock-md-to-clipboard ()
  "Generate today's clocktable (Markdown) and copy to the OS clipboard."
  (interactive)
  (let* ((md (zk/--clock-md))
         (method (zk/--copy-to-system-clipboard md)))
    (message (pcase method
               ('w32      "Copied to Windows clipboard.")
               ('pbcopy   "Copied to macOS clipboard.")
               ('wl-copy  "Copied via wl-copy.")
               ('xclip    "Copied via xclip.")
               ('xsel     "Copied via xsel.")
               ('clip.exe "Copied via clip.exe (WSL).")
               ('kill-ring "No system clipboard tool; copied to Emacs kill-ring only.")))))

;; Optional: ensure Emacs uses the OS clipboard when possible
(setq select-enable-clipboard t)
