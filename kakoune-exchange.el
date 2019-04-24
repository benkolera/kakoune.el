;;; kakoune-exchange.el --- Exchange function for kakoune.el -*- lexical-binding: t; -*-
;; Author: Joseph Morag <jm4157@columbia.edu>
;;; Commentary:
;; A ripoff of evil-exchange https://github.com/Dewdrops/evil-exchange, which is a port of Tim Pope's vim-exchange. Provides two commands,
;; (kakoune-exchange) and (kakoune-exchange-cancel)

;;; Code:
(require 'cl-lib)
(require 'ryo-modal)
(require 'expand-region)
(require 'multiple-cursors)

(defcustom kakoune-exchange-highlight-face 'highlight
  "Face used to highlight marked area."
  :type 'sexp
  :group 'kakoune-exchange)

(defvar kakoune-exchange--position nil "Text position which will be exchanged.")

(defvar kakoune-exchange--overlays nil "Overlays used to highlight marked area.")

(defun kakoune-exchange--highlight (beg end)
  (let ((o (make-overlay beg end nil t nil)))
    (overlay-put o 'face kakoune-exchange-highlight-face)
    (add-to-list 'kakoune-exchange--overlays o)))

(defun kakoune-exchange--clean ()
  (setq kakoune-exchange--position nil)
  (mapc 'delete-overlay kakoune-exchange--overlays)
  (setq kakoune-exchange--overlays nil))

(defun kakoune-exchange (beg end)
  "Exchange two regions."
  (interactive "r")
  (let ((beg-marker (copy-marker beg t))
        (end-marker (copy-marker end nil)))
    (if (null kakoune-exchange--position)
        ;; call without kakoune-exchange--position set: store region
        (progn
          (setq kakoune-exchange--position (list (current-buffer) beg-marker end-marker))
          ;; highlight area marked to exchange
          (kakoune-exchange--highlight beg end))
      ;; secondary call: do exchange
      (cl-destructuring-bind
          (orig-buffer orig-beg orig-end) kakoune-exchange--position
        (kakoune-exchange--do-swap (current-buffer) orig-buffer
                                   beg-marker end-marker
                                   orig-beg orig-end
                                   #'delete-and-extract-region #'insert)))))

(defun kakoune-exchange--do-swap (curr-buffer orig-buffer curr-beg curr-end orig-beg
                                              orig-end extract-fn insert-fn)
  "This function does the real exchange work. Here's the detailed steps:
1. call extract-fn with orig-beg and orig-end to extract orig-text.
2. call extract-fn with curr-beg and curr-end to extract curr-text.
3. go to orig-beg and then call insert-fn with curr-text.
4. go to curr-beg and then call insert-fn with orig-text.
After step 2, the two markers of the same beg/end pair (curr or orig)
will point to the same position. So if orig-beg points to the same position
of curr-end initially, orig-beg and curr-beg will point to the same position
before step 3. Because curr-beg is a marker which moves after insertion, the
insertion in step 3 will push it to the end of the newly inserted text,
thus resulting incorrect behaviour.
To fix this edge case, we swap two extracted texts before step 3 to
effectively reverse the (problematic) order of two `kakoune-exchange' calls."
  (if (eq curr-buffer orig-buffer)
      ;; in buffer exchange
      (let ((adjacent  (equal (marker-position orig-beg) (marker-position curr-end)))
            (orig-text (funcall extract-fn orig-beg orig-end))
            (curr-text (funcall extract-fn curr-beg curr-end)))
        ;; swaps two texts if adjacent is set
        (let ((orig-text (if adjacent curr-text orig-text))
              (curr-text (if adjacent orig-text curr-text)))
          (save-excursion
            (goto-char orig-beg)
            (funcall insert-fn curr-text)
            (goto-char curr-beg)
            (funcall insert-fn orig-text))))
    ;; exchange across buffers
    (let ((orig-text (with-current-buffer orig-buffer
                       (funcall extract-fn orig-beg orig-end)))
          (curr-text (funcall extract-fn curr-beg curr-end)))
      (save-excursion
        (with-current-buffer orig-buffer
          (goto-char orig-beg)
          (funcall insert-fn curr-text))
        (goto-char curr-beg)
        (funcall insert-fn orig-text))))
  (kakoune-exchange--clean))

(defun kakoune-exchange-cancel ()
  "Cancel current pending exchange."
  (interactive)
  (if (null kakoune-exchange--position)
      (message "No pending exchange")
    (kakoune-exchange--clean)
    (message "Exchange cancelled")))

(provide 'kakoune-exchange)
;;; kakoune-exchange.el ends here
