;;; sort-tab.el --- Provide an out of box configuration to use tab in Emacs.

;; Filename: sort-tab.el
;; Description: Provide an out of box configuration to use sort-tab in Emacs.
;; Author: Andy Stewart <lazycat.manatee@gmail.com>
;; Maintainer: Andy Stewart <lazycat.manatee@gmail.com>
;; Copyright (C) 2021, Andy Stewart, all rights reserved.
;; Created: 2021-10-26 22:14:34
;; Version: 1.0
;; Last-Updated: 2021-10-26 22:14:34
;;           By: Andy Stewart
;; URL: http://www.emacswiki.org/emacs/download/sort-tab.el
;; Keywords:
;; Compatibility: GNU Emacs 27.0.50
;;
;; Features that might be required by this library:
;;
;;

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Provide an out of box configuration to use tab in Emacs.
;;

;;; Installation:
;;
;; Put sort-tab.el to your load-path.
;; The load-path is usually ~/elisp/.
;; It's set in your ~/.emacs like this:
;; (add-to-list 'load-path (expand-file-name "~/elisp"))
;;
;; And the following to your ~/.emacs startup file.
;;
;; (require 'sort-tab)
;; (sort-tab-mode t)
;;
;; No need more.
;;

(defgroup sort-tab nil
  "Display sort-tab in top of Emacs."
  :group 'convenience)

(defcustom sort-tab-buffer "*sort-tab*"
  "The buffer name of sort-tab."
  :type 'string)

(defcustom sort-tab-height 30
  "The height of sort-tab."
  :type 'integer)

(defface sort-tab-current-tab-face
  '((((background light))
     :background "#d5c9c0" :foreground "#282828"
     :bold t :inherit mode-line-active)
    (t
     :background "#504945" :foreground "#fbf1c7"
     :bold t :inherit mode-line-active))
  "Face for current tab.")

(defface sort-tab-inactive-tab-face
  '((((background light))
     :foreground "#665c54" :inherit 'mode-line-active)
    (t
     :foreground "#bdae93" :bold nil :inherit 'mode-line-active))
  "Face for inactive tabs.")

(defface sort-tab-separator-face
  '((((background light))
     :foreground "#bdae93" :bold t :inherit 'mode-line-active)
    (t
     :foreground "#665c54" :bold t :inherit 'mode-line-active))
  "Face for separator.")

(defvar sort-tab-mode-map
  (let ((km (make-sparse-keymap)))
    km)
  "Keymap to use in sort-tab mode.")

(defvar sort-tab-window nil)

(defvar sort-tab-buffer-freq-count-timer nil
  "Timer used for count buffer used frequency.")

(defvar-local sort-tab-buffer-freq 0
  "Used frequency of current buffer.")

(defvar sort-tab-count-freq-idle-time 1
  "Add used frequency after being idle for this much secs.")

(defvar sort-tab-visible-buffers nil)

(defvar sort-tab-inhibit-resort nil)

(define-minor-mode sort-tab-mode
  "Toggle display of a sort-tab.
With prefix argument ARG, turn on if positive, otherwise off.
Returns non-nil if the new state is enabled.

\\{sort-tab-mode-map}"
  :group 'sort-tab
  :require 'sort-tab
  :global t
  :keymap sort-tab-mode-map
  (if sort-tab-mode
      (sort-tab-turn-on)
    (sort-tab-turn-off)))

(defun sort-tab-turn-on ()
  (interactive)
  ;; Create sort-tab buffer.
  (generate-new-buffer sort-tab-buffer)
  (with-current-buffer sort-tab-buffer
    ;; Disable line numbers mode.
    (when display-line-numbers
      (setq-local display-line-numbers nil))
    ;; Disable tab-line.
    (when (version< "27.0" emacs-version)
      (setq-local tab-line-format nil))
    ;; Disable hl-line, header-line and mode-line in input buffer.
    (setq-local header-line-format nil)
    (setq-local mode-line-format nil)
    ;; Disable cursor type if option `disable-cursor' is non-nil.
    (setq-local cursor-type nil)
    ;; Set Mini height to make sure sort-tab window always 1-line height.
    (setq-local window-min-height 1)
    ;; Disable wrap line.
    (setq-local truncate-lines t))

  ;; Create sort-tab window.
  (sort-tab-create-window)

  ;; Start count buffer frequency.
  (sort-tab-start-count-freq)

  ;; Update sort-tab buffer list.
  (sort-tab-update-list)

  ;; Add update hook.
  (add-hook 'buffer-list-update-hook #'sort-tab-update-list))

(defun sort-tab-create-window ()
  ;; Split top window.
  (ignore-errors
    (dotimes (i 50)
      (windmove-up)))
  (split-window-vertically 1)

  ;; Record sort-tab window.
  (setq sort-tab-window (selected-window))
  (switch-to-buffer sort-tab-buffer)
  (other-window 1)

  ;; Set window dedicated to make sure pop buffer won't use sort-tab window.
  (set-window-dedicated-p sort-tab-window t)

  ;; Make sure sort-tab window can skip `delete-other-windows' and 'other-window'.
  (set-window-parameter sort-tab-window 'no-delete-other-windows t)
  (set-window-parameter sort-tab-window 'window-side 'top)
  (set-window-parameter sort-tab-window 'window-slot 0)
  (set-window-parameter sort-tab-window 'no-other-window t))

(defun sort-tab-turn-off ()
  (interactive)
  (when (sort-tab-live-p)
    ;; Reset window parameter.
    (set-window-parameter sort-tab-window 'no-delete-other-windows nil)
    (set-window-parameter sort-tab-window 'window-side nil)
    (set-window-parameter sort-tab-window 'window-slot nil)
    (set-window-parameter sort-tab-window 'no-other-window nil)

    ;; Kill sort-tab window.
    (ignore-errors
      (with-current-buffer sort-tab-buffer
        (kill-buffer-and-window))))

  ;; Reset sort-tab window.
  (setq sort-tab-window nil)

  ;; Stop count.
  (sort-tab-stop-count-freq)

  ;; Remove update hook.
  (remove-hook 'buffer-list-update-hook #'sort-tab-update-list))

(defun sort-tab-live-p ()
  (and (buffer-live-p (get-buffer sort-tab-buffer))
       sort-tab-window
       (window-live-p sort-tab-window)))

(defun sort-tab-increase-buffer-freq ()
  "Increase the used frequency of current buffer by 1."
  (cl-incf sort-tab-buffer-freq))

(defun sort-tab-start-count-freq ()
  "Start counting buffer used frequency."
  (setq sort-tab-buffer-freq-count-timer
        (run-with-idle-timer sort-tab-count-freq-idle-time
                             t #'sort-tab-increase-buffer-freq)))

(defun sort-tab-stop-count-freq ()
  "Stop counting buffer used frequency."
  (cancel-timer sort-tab-buffer-freq-count-timer)
  (setq sort-tab-buffer-freq-count-timer nil))

(defun sort-tab-buffer-freq (buf)
  "Return the used frequency of buffer BUF."
  (or (buffer-local-value 'sort-tab-buffer-freq buf)
      0))

(defun sort-tab-buffer-freq-higher-p (buf1 buf2)
  "Return t if the used frequency of BUF1 is higher than BUF2."
  (> (sort-tab-buffer-freq buf1)
     (sort-tab-buffer-freq buf2)))

(defun sort-tab-buffer-need-hide-p (buf)
  (let* ((name (buffer-name buf)))
    (cond
     ((eq (aref name 0) ?\s) t)
     ((string-prefix-p " *" name) t)
     ((string-prefix-p "*" name) t)
     )))

(defun sort-tab-update-list ()
  (unless (window-minibuffer-p)
    (let ((current-buffer (current-buffer))
          (current-buffer-name (buffer-name))
          (current-tab-start-column 0)
          (current-tab-end-column 0)
          found-current-tab
          tab-separator
          tab)
      (with-current-buffer sort-tab-buffer
        ;; Clean buffer.
        (erase-buffer)

        ;; Don't sort tabs if using sort-tab commands.
        (unless sort-tab-inhibit-resort
          (setq sort-tab-visible-buffers (append (list current-buffer) (sort-tab-get-other-buffer-list current-buffer-name))))

        (dolist (buf sort-tab-visible-buffers)
          ;; Insert tab.
          (setq tab (if (eq buf current-buffer)
                        (propertize (format " %s " (buffer-name buf)) 'face 'sort-tab-current-tab-face)
                      (propertize (format " %s " (buffer-name buf)) 'face 'sort-tab-inactive-tab-face)))
          (setq tab-separator (propertize (format "|" (buffer-name buf)) 'face 'sort-tab-separator-face))
          (insert tab)
          (insert tab-separator)

          ;; Calculate the current tab column.
          (unless found-current-tab
            (when (eq buf current-buffer)
              (setq found-current-tab t)
              (setq current-tab-start-column current-tab-end-column))
            (setq current-tab-end-column (+ current-tab-end-column (length tab) (length tab-separator)))))

        ;; Make tab always visible.
        (with-selected-window (get-buffer-window sort-tab-buffer)
          (cond ((> current-tab-end-column (+ (window-hscroll) (window-width)))
                 (scroll-left (- current-tab-end-column (window-hscroll) (window-width))))
                ((< current-tab-start-column (window-hscroll))
                 (set-window-hscroll (get-buffer-window sort-tab-buffer) current-tab-start-column))
                ))))))

(defun sort-tab-get-other-buffer-list (current-buffer-name)
  (let ((bufs (buffer-list)))
    (setq bufs (cl-remove-if (lambda (buf) (or (eq (buffer-name buf) current-buffer-name))) bufs))
    (setq bufs (cl-remove-if #'sort-tab-buffer-need-hide-p bufs))
    (setq bufs (sort bufs #'sort-tab-buffer-freq-higher-p))
    bufs))

(defun sort-tab-select-prev-tab ()
  (interactive)
  (let* ((sort-tab-inhibit-resort t)
         (buf (current-buffer))
         (index (cl-position buf sort-tab-visible-buffers :test #'eq)))
    (cond
     ((or (null index) (eq index 0))
      (switch-to-buffer (car (last sort-tab-visible-buffers))))
     (t
      (switch-to-buffer (nth (1- index) sort-tab-visible-buffers))))))

(defun sort-tab-select-next-tab ()
  (interactive)
  (let* ((sort-tab-inhibit-resort t)
         (buf (current-buffer))
         (index (cl-position buf sort-tab-visible-buffers :test #'eq)))
    (cond
     ((or (null index) (eq index (1- (length sort-tab-visible-buffers))))
      (switch-to-buffer (car sort-tab-visible-buffers)))
     (t
      (switch-to-buffer (nth (1+ index) sort-tab-visible-buffers))))))

(defun sort-tab-select-first-tab ()
  (interactive)
  (let* ((sort-tab-inhibit-resort t))
    (switch-to-buffer (first sort-tab-visible-buffers))))

(defun sort-tab-select-last-tab ()
  (interactive)
  (let* ((sort-tab-inhibit-resort t))
    (switch-to-buffer (car (last sort-tab-visible-buffers)))))

;; Eldoc always change user's buffer name, it's annoying.
;; This advice just remove feature that show eldoc message in echo area.
(defun sort-tab-eldoc-advisor (orig-fun &optional arg &rest args)
  (with-current-buffer eldoc--doc-buffer
    (setq buffer-read-only nil)
    (erase-buffer))
  eldoc--doc-buffer)
(advice-add #'eldoc--format-doc-buffer :around #'sort-tab-eldoc-advisor)

(provide 'sort-tab)

;;; sort-tab.el ends here