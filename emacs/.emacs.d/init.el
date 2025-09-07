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
