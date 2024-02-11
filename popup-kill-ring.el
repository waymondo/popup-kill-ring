;;; popup-kill-ring.el --- interactively insert item from kill-ring

;; Copyright (C) 2010-2015  HAMANO Kiyoto

;; Author: HAMANO Kiyoto <khiker.mail+elisp@gmail.com>
;; Keywords: popup, kill-ring, pos-tip
;; Package-Requires: ((pos-tip "0.4.6") (popup "0.5.9"))
;; Homepage: https://github.com/waymondo/popup-kill-ring

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Manage your `kill-ring' (select and paste).

;;; Requirement:
;;
;; * popup.el   http://github.com/m2ym/auto-complete
;; * pos-tip.el http://www.emacswiki.org/emacs/PosTip

;;; Setting:
;;
;; 1. Download the `popup.el', `pos-tip.el' and this file.
;; 2. Put your `load-path' directory to the `popup.el', `pos-tip.el'
;;    and this file.
;; 3. Add following settings to your .emacs.
;;
;;   (require 'popup)
;;   (require 'pos-tip)
;;   (require 'popup-kill-ring)
;;
;;   (global-set-key "\M-y" 'popup-kill-ring) ; For example.
;;
;; * If you insert a selected item interactively, add following line to
;;   your .emacs.
;;
;;   (setq popup-kill-ring-interactive-insert t)

;;; Tested:
;;
;; * Emacs
;;   * 29.1
;; * popup.el
;;   * 0.5.9
;; * pos-tip.el
;;   * 0.4.6
;;

;;; ChangeLog:
;;
;; * 1.0.0
;;   Updated to work with lexically-scoped popup changes.
;;   Removed functions and vars related to popup-kill-ring-kill-ring-show-func.
;;
;; * 0.2.11 (2015/03/22)
;;   Minor fixes (apply diffs of EmacsWiki, use defcustom and so on ...)
;;
;; * 0.2.10 (2015/03/22)
;;   To check whether the pos-tip can use, use `display-graphic-p'
;;   instead of (eq window-system 'x). (This bug was reported by
;;   id:ganaware. Thank you.)
;;
;; * 0.2.9 (2014/11/25)
;;   Use cl-lib instead of cl.
;;
;; * 0.2.8 (2011/06/10)
;;   Added the new variable `popup-kill-ring-last-used-move-first'.  If
;;   this variable is non-nil, It means that last selected `kill-ring'
;;   item comes first of `kill-ring'. This value is `t' by default.
;;
;; * 0.2.7 (2010/05/05)
;;   If `popup-kill-ring-interactive-insert' is `t' and
;;   `C-g' was typed, clear the inserted string.
;;
;; * 0.2.6 (2010/05/05)
;;   Change `popup-kill-ring' to execute `pos-tip-hide' at all time.
;;
;; * 0.2.5 (2010/05/02)
;;   When `point' is on minibuffer, do ordinary `yank' command.
;;
;; * 0.2.4 (2010/05/01)
;;   Fixed change a place the doing `receter'.
;;
;; * 0.2.3 (2010/05/01)
;;   Add variable `popup-kill-ring-interactive-insert-face'.
;;   Now add face for interactive inserted string when
;;   `popup-kill-ring-interactive-insert-face' is `t'.
;;
;; * 0.2.2 (2010/04/29)
;;   Fix the broken `popup-menu*' overlay window when
;;   `popup-kill-ring-interactive-insert' is `t'.
;;
;; * 0.2.1 (2010/04/29)
;;   New variable `popup-kill-ring-item-size-max'.
;;   Now tested on `pos-tip' 0.3.6
;;
;; * 0.2.0 (2010/04/29)
;;   New variable `popup-kill-ring-popup-margin-left'
;;   New variable `popup-kill-ring-isearch'
;;   New variable `popup-kill-ring-item-min-width'
;;   Now `isearch' argument of `popup-menu*' is `t' by default.
;;   If the length of item of `kill-ring' was shorter than
;;   `popup-kill-ring-item-min-width', Now discards it.
;;
;; * 0.1.0
;;   New variable `popup-kill-ring-interactive-insert'.
;;
;; * 0.0.9
;;   Bug fix for `popup-kill-ring-previous'.
;;   New variable `popup-kill-ring-pos-tip-color'.
;;   Fix document of this file.
;;
;; * 0.0.8
;;   Modify keymap setting.
;;
;; * 0.0.7
;;   Added the function `popup-kill-ring-current'.
;;   Added the function `popup-kill-ring-hide'.
;;
;; * 0.0.6
;;   `up' to `popup-kill-ring-popup-previous'.
;;   `down' to `popup-kill-ring-popup-next'.
;;
;; * 0.0.5
;;   New variable `popup-kill-ring-kill-ring-show-func'.
;;   New Variable `popup-kill-ring-keymap'.
;;
;; * 0.0.4
;;   abolished the substring of menu item.
;;   set margin-right and width to `popup-menu*'.
;;
;; * 0.0.3
;;   `pos-tip-show' argument `DY' to 0.
;;
;; * 0.0.2
;;   `with-no-warnings' for variable `menu'.
;;
;; * 0.0.1:
;;   Initial version.

;;; Code:

(require 'popup)
(require 'pos-tip)
(require 'seq)

(eval-when-compile
  (require 'cl-lib))

;;; Variables:

(defgroup popup-kill-ring nil
  "interactively insert item from kill-ring"
  :group  'convenience
  :prefix "popup-kill-ring-")

(defconst popup-kill-ring-version "1.0.0"
  "Version of `popup-kill-ring'")

(defcustom popup-kill-ring-popup-width 30
  "Width of popup item."
  :type  'integer
  :group 'popup-kill-ring)

(defcustom popup-kill-ring-popup-margin-left 2
  "Width of `popup-menu*' margin-left."
  :type 'integer
  :group 'popup-kill-ring)

(defcustom popup-kill-ring-popup-margin-right 2
  "Width of `popup-menu*' margin-right."
  :type 'integer
  :group 'popup-kill-ring)

(defcustom popup-kill-ring-interactive-insert nil
  "Non-nil means that insert selected item of `popup-menu*' interactively."
  :type 'boolean
  :group 'popup-kill-ring)

(defcustom popup-kill-ring-isearch t
  "Non-nil means that passes `t' to `isearch' option of `popup-menu*'"
  :type 'boolean
  :group 'popup-kill-ring)

(defcustom popup-kill-ring-item-min-width 3
  "The number that shows minimum width of displaying `kill-ring' item
of `popup-menu*'"
  :type 'integer
  :group 'popup-kill-ring)

(defcustom popup-kill-ring-item-size-max nil
  "The number that means max each item size of `popup-menu'.
If item size is longer than this number, it's truncated.
Nil means that item does not be truncate."
  :type 'integer
  :group 'popup-kill-ring)

(defcustom popup-kill-ring-interactive-insert-face 'highlight
  "The face for interactively inserted string when
`popup-kill-ring-interactive-insert' is `t'."
  :type 'face
  :group 'popup-kill-ring)

(defcustom popup-kill-ring-last-used-move-first t
  "Non-nil means that last selected `kill-ring' item comes first of
`kill-ring'."
  :type 'boolean
  :group 'popup-kill-ring)

(defvar popup-kill-ring-keymap
  (let ((keymap (make-sparse-keymap)))
    (set-keymap-parent keymap popup-menu-keymap)
    (define-key keymap "\C-n" 'popup-kill-ring-next)
    (define-key keymap "\C-p" 'popup-kill-ring-previous)
    keymap))

(defvar popup-kill-ring--interactive-region-start nil)
(defvar popup-kill-ring--interactive-region-end nil)

;;;###autoload
;;; Functions:


(defun popup-kill-ring ()
  (interactive)
  (cond
   ((minibufferp)
    (yank))
   (t (let ((kring (popup-kill-ring--convert-kill-ring)))
        (when popup-kill-ring-interactive-insert
          (setq popup-kill-ring--interactive-region-start (point))
          (popup-kill-ring--interactive-insert-item (nth 0 kring)))
        (unwind-protect
            (let ((item (popup-menu* kring
                                     :keymap popup-kill-ring-keymap
                                     :width popup-kill-ring-popup-width
                                     :margin-left popup-kill-ring-popup-margin-left
                                     :margin-right popup-kill-ring-popup-margin-right
                                     :scrollbar t
                                     :isearch popup-kill-ring-isearch
                                     :symbol 'popup-kill-ring)))
              (when (and item (not popup-kill-ring-interactive-insert)) (insert item)))
          (pos-tip-hide)
          (when (and popup-kill-ring-interactive-insert
                     (numberp last-input-event)
                     (= last-input-event 7))
            (popup-kill-ring--clear-interactive-insert)
          ))))))

(defun popup-kill-ring--get-current-popup ()
  (seq-find (lambda (p) (eq (popup-symbol p) 'popup-kill-ring)) popup-instances))

(defun popup-kill-ring--get-item (&optional offset)
  (let ((current-popup (popup-kill-ring--get-current-popup)))
    (nth (+ (or offset 0) (popup-cursor current-popup)) current-popup)))

(defun popup-kill-ring--convert-kill-ring ()
  (let ((index -1)
        (kring (if popup-kill-ring-last-used-move-first (reverse kill-ring) kill-ring)))
    (mapcar
     (lambda (killed-item)
       (setq index (1+ index))
       (propertize
        (with-temp-buffer
          (erase-buffer)
          (insert (replace-regexp-in-string
                   "[ \t]+" " "
                   (replace-regexp-in-string
                    "\n" " " killed-item)))
          (cond
           ((and popup-kill-ring-item-size-max
                (>= (point-max) popup-kill-ring-item-size-max))
           (setq p-max popup-kill-ring-item-size-max))
           (t (setq p-max (point-max))))
          (buffer-substring-no-properties (point-min) p-max))
        'index index
        'summary (concat "(" (int-to-string index) ")")))
     kring)))

(defun popup-kill-ring-next ()
  (interactive)
  (let* ((current-popup (popup-kill-ring--get-current-popup))
         (current-index (popup-cursor current-popup))
         (max-index (1- (length (popup-list current-popup))))
         (next-index (if (>= (1+ current-index) max-index) max-index (1+ current-index))))
    (when (not (eq current-index next-index))
      (when popup-kill-ring-interactive-insert
        (let ((current-item (nth current-index (popup-list current-popup)))
              (next-item (nth next-index (popup-list current-popup))))
          (popup-kill-ring--clear-interactive-insert)
          (popup-kill-ring--interactive-insert-item next-item)))
      (popup-next current-popup))))

(defun popup-kill-ring-previous ()
  (interactive)
  (let* ((current-popup (popup-kill-ring--get-current-popup))
         (current-index (popup-cursor current-popup))
         (prev-index (if (<= (1- current-index) 0) 0 (1- current-index))))
    (when (not (eq current-index prev-index))
      (when popup-kill-ring-interactive-insert
        (let ((current-item (nth current-index (popup-list current-popup)))
              (previous-item (nth prev-index (popup-list current-popup))))
          (popup-kill-ring--clear-interactive-insert)
          (popup-kill-ring--interactive-insert-item previous-item)))
      (popup-previous current-popup))))

(defun popup-kill-ring--interactive-insert-item (item)
  (let* ((start (point))
         (end (+ start (length item)))
         ol)
    (setq popup-kill-ring--interactive-region-end end)
    (unwind-protect
        (with-timeout (1.0 (if ol (delete-overlay)))
          (insert item)
          (recenter)
          (setq ol (make-overlay start end))
          (overlay-put ol 'face popup-kill-ring-interactive-insert-face)
          (sit-for 0.15))
      (if ol (delete-overlay ol)))))

(defun popup-kill-ring--clear-interactive-insert ()
  (when popup-kill-ring-interactive-insert
    (delete-region popup-kill-ring--interactive-region-start popup-kill-ring--interactive-region-end)
    (goto-char popup-kill-ring--interactive-region-start)))

(provide 'popup-kill-ring)

;; Local Variables:
;; indent-tabs-mode: nil
;; End:

;;; popup-kill-ring.el ends here
