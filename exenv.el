;;; exenv.el --- Emacs integration for exenv

;; Copyright (C) 2014 Michael Simpson

;; URL: https://github.com/mjs2600/exenv.el
;; Author: Michael Simpson <mjs2600@gmail.com>
;; Version: 0.0.3
;; Created: 20 November 2014
;; Keywords: elixir exenv

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; M-x global-exenv-mode toggle the configuration done by exenv.el

;; M-x exenv-use-global prepares the current Emacs session to use
;; the global Elixir configured with exenv.

;; M-x exenv-use allows you to switch the current session to the Elixir
;; implementation of your choice.

;;; Compiler support:

;; helper function used in variable definitions
(defcustom exenv-installation-dir (or (getenv "EXENV_ROOT")
                                      (concat (getenv "HOME") "/.exenv/"))
  "The path to the directory where exenv was installed."
  :group 'exenv
  :type 'directory)

(defun exenv--expand-path (&rest segments)
  (let ((path (mapconcat 'identity segments "/"))
        (installation-dir (replace-regexp-in-string "/$" "" exenv-installation-dir)))
    (expand-file-name (concat installation-dir "/" path))))

(defcustom exenv-interactive-completion-function
  (if ido-mode 'ido-completing-read 'completing-read)
  "The function which is used by exenv.el to interactivly complete user input"
  :group 'exenv
  :type 'function)

(defcustom exenv-show-active-elixir-in-modeline t
  "Toggles whether exenv-mode shows the active Elixir in the modeline."
  :group 'exenv
  :type 'boolean)

(defcustom exenv-modeline-function 'exenv--modeline-with-face
  "Function to specify the exenv representation in the modeline."
  :group 'exenv
  :type 'function)

(defvar exenv-executable (exenv--expand-path "bin" "exenv")
  "path to the exenv executable")

(defvar exenv-elixir-shim (exenv--expand-path "shims" "elixir")
  "path to the Elixir shim executable")

(defvar exenv-global-version-file (exenv--expand-path "version")
  "path to the global version configuration file of exenv")

(defvar exenv-version-environment-variable "EXENV_VERSION"
  "name of the environment variable to configure the exenv version")

(defvar exenv-binary-paths (list (cons 'shims-path (exenv--expand-path "shims"))
                                 (cons 'bin-path (exenv--expand-path "bin")))
  "these are added to PATH and exec-path when exenv is setup")

(defface exenv-active-elixir-face
  '((t (:weight bold :foreground "Purple")))
  "The face used to highlight the current Elixir on the modeline.")

(defvar exenv--initialized nil
  "indicates if the current Emacs session has been configured to use exenv")

(defvar exenv--modestring nil
  "text exenv-mode will display in the modeline.")
(put 'exenv--modestring 'risky-local-variable t)

;;;###autoload
(defun exenv-use-global ()
  "activate exenv global Elixir"
  (interactive)
  (exenv-use (exenv--global-elixir-version)))

;;;###autoload
(defun exenv-use-corresponding ()
  "search for .elixir-version or .exenv-version and activate the corresponding Elixir"
  (interactive)
  (let ((version-file-path (or (exenv--locate-file ".elixir-version")
                               (exenv--locate-file ".exenv-version"))))
    (if version-file-path (exenv-use (exenv--read-version-from-file version-file-path))
      (message "[exenv] could not locate .elixir-version or .exenv-version"))))

;;;###autoload
(defun exenv-use (elixir-version)
  "Choose which Elixir you want to activate"
  (interactive
   (let ((picked-elixir (exenv--completing-read "Elixir version: " (exenv/list))))
     (list picked-elixir)))
  (exenv--activate elixir-version)
  (message (concat "[exenv] using " elixir-version)))

(defun exenv/list ()
  (append '("system")
          (split-string (exenv--call-process "versions" "--bare") "\n")))

(defun exenv--setup ()
  (when (not exenv--initialized)
    (dolist (path-config exenv-binary-paths)
      (let ((bin-path (cdr path-config)))
        (setenv "PATH" (concat bin-path ":" (getenv "PATH")))
        (add-to-list 'exec-path bin-path)))
    (setq eshell-path-env (getenv "PATH"))
    (setq exenv--initialized t)
    (exenv--update-mode-line)))

(defun exenv--teardown ()
  (when exenv--initialized
    (dolist (path-config exenv-binary-paths)
      (let ((bin-path (cdr path-config)))
        (setenv "PATH" (replace-regexp-in-string (regexp-quote (concat bin-path ":")) "" (getenv "PATH")))
        (setq exec-path (remove bin-path exec-path))))
    (setq eshell-path-env (getenv "PATH"))
    (setq exenv--initialized nil)))

(defun exenv--activate (elixir-version)
  (setenv exenv-version-environment-variable elixir-version)
  (exenv--update-mode-line))

(defun exenv--completing-read (prompt options)
  (funcall exenv-interactive-completion-function prompt options))

(defun exenv--global-elixir-version ()
  (if (file-exists-p exenv-global-version-file)
      (exenv--read-version-from-file exenv-global-version-file)
    "system"))

(defun exenv--read-version-from-file (path)
  (with-temp-buffer
    (insert-file-contents path)
    (exenv--replace-trailing-whitespace (buffer-substring-no-properties (point-min) (point-max)))))

(defun exenv--locate-file (file-name)
  "searches the directory tree for an given file. Returns nil if the file was not found."
  (let ((directory (locate-dominating-file default-directory file-name)))
    (when directory (concat directory file-name))))

(defun exenv--call-process (&rest args)
  (with-temp-buffer
    (let* ((success (apply 'call-process exenv-executable nil t nil
                           (delete nil args)))
           (raw-output (buffer-substring-no-properties
                        (point-min) (point-max)))
           (output (exenv--replace-trailing-whitespace raw-output)))
      (if (= 0 success)
          output
        (message output)))))

(defun exenv--replace-trailing-whitespace (text)
  (replace-regexp-in-string "[[:space:]\n]+\\'" "" text))

(defun exenv--update-mode-line ()
  (setq exenv--modestring (funcall exenv-modeline-function
                                   (exenv--active-elixir-version))))

(defun exenv--modeline-with-face (current-elixir)
  (append '(" [")
          (list (propertize current-elixir 'face 'exenv-active-elixir-face))
          '("]")))

(defun exenv--modeline-plain (current-elixir)
  (list " [" current-elixir "]"))

(defun exenv--active-elixir-version ()
  (or (getenv exenv-version-environment-variable) (exenv--global-elixir-version)))

;;;###autoload
(define-minor-mode global-exenv-mode
  "use exenv to configure the Elixir version used by your Emacs."
  :global t
  (if global-exenv-mode
      (progn
        (when exenv-show-active-elixir-in-modeline
          (unless (memq 'exenv--modestring global-mode-string)
            (setq global-mode-string (append (or global-mode-string '(""))
                                             '(exenv--modestring)))))
        (exenv--setup))
    (setq global-mode-string (delq 'exenv--modestring global-mode-string))
    (exenv--teardown)))

(provide 'exenv)

;;; exenv.el ends here
