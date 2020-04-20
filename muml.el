;;; muml.el --- Minor mode for displaying the number of results of a
;;; mu (mu4e) query in the mode-line

;; Copyright (C) 2019 Steven Meunier

;; Author: Steven Meunier <gh@solaryeti.com>
;; Maintainer: Steven Meunier <gh@solaryeti.com>
;; Created: 1 Nov 2014
;; Version: 0.1.1
;; Keywords: convenience email
;; URL: https://github.com/solaryeti/muml

;; This file is not part of GNU Emacs.

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

;; Provides a visual indicator on the mode-line displaying the number
;; of results for a particular mu search query.

;; Configuration:
;; Add the following to your Emacs config to enable muml:
;;   (require 'muml)
;;   (turn-on-muml-mode)

;; The query used can be customised by setting 'muml-query.  For
;; example, to query for unread mail use:
;;   (setq muml-query "flag:unread")

;; This is the default value for 'muml-query.

;; You can also query using a bookmark as follows:
;;   (setq muml-bookmark "Unread messages")

;; This variable has precedence over 'muml-query but the
;; query will default to that of 'muml-query if the bookmark
;; cannot be found.

;; If using a bookmark be sure to turn on muml after you configure
;; your mu4e bookmarks.  If not, then your bookmark will not be found
;; on the initial setting of the mode-line.

;; Updating the query count:
;; muml makes use of multiple hooks to update the message
;; count.  However, it is possible that under certain situations the
;; count might not get updated.  In this case, you can manually trigger
;; an update by running:
;;   M-x muml-update

;; Displaying the query count with muml disabled:
;; If you do not want to have muml permanently displaying in your
;; mode-line but would like to know if there is any mail waiting for
;; you without switching to mu4e, you can run the following command to
;; display the count of your chosen query or bookmark in the echo
;; area:
;;   M-x muml-display-query-count

;; Inspired by lunar-phase-mode.el by Ben Voui <intrigeri@boum.org>
;; (https://github.com/atykhonov/lunar-mode-line)

;;; Install:

;; Add this file to your Emacs-Lisp load path, or load it explicitly
;; by adding the following to your ~/.emacs.d/init.el:
;;     (load-file "/path/to/muml.el")

;;; Usage:

;; Add the following to your emacs config to enable muml:
;;     (require 'muml)
;;     (turn-on-muml-mode)

;; The query used can be customised by setting 'muml-query. For
;; example, to query for unread mail use:
;;     (setq muml-query "flag:unread")
;; This is the default value for 'muml-query.
;;
;; You can also query using a bookmark as follows:
;;     (setq muml-bookmark "Unread messages")
;; This variable has precedence over 'muml-query but the
;; query will default to that of 'muml-query if the bookmark
;; cannot be found.
;;
;; If using a bookmark be sure to turn on muml after you
;; configure your mu4e bookmarks. If not, then your bookmark will not
;; be found on the initial setting of the mode-line.

;;; Code:
(require 'mu4e-vars)

(defgroup muml nil
  "display count of mu query in the mode-line"
  :group 'modeline)

(defcustom muml-prefix "✉"
  "Text to display before the query result in the mode-line."
  :type 'string
  :group 'muml)

(defcustom muml-query "flag:unread"
  "Query used for count displayed in mode-line."
  :type 'string
  :group 'muml)

(defcustom muml-bookmark nil
  "A mu4e bookmark to be used for the message count.

This option takes precedence over 'muml-query."
  :type 'string
  :group 'muml)

(defcustom muml-hide-mode-line-when-zero nil
  "Disable the mode-line when the message count is zero."
  :type 'boolean
  :group 'muml)

(defvar muml-string nil
  "String to display in the mode line.")

(put 'muml-string 'risky-local-variable t)

;;;###autoload
(define-minor-mode muml-mode
  :global t
  :group 'muml
  :init-value t
  :require 'muml
  (setq muml-string "")
  (or global-mode-string (setq global-mode-string '("")))
  (if muml-mode
      (muml--enable-mode-line)
    (muml--disable-mode-line)))

;;;###autoload
(defun muml-display-query-count ()
  "Display the query count in the echo area."
  (interactive)
  (message "✉%s"
           (muml--count-query-results (muml--query))))

;;;###autoload
(defun turn-on-muml-mode ()
  "Turn on `muml-mode'."
  (interactive)
  (muml-mode t))

;;;###autoload
(defun turn-off-muml-mode ()
  "Turn off `muml-mode'."
  (interactive)
  (muml-mode -1))

(defun muml--enable-mode-line ()
  "Enable muml in the mode-line."
  (add-to-list 'global-mode-string 'muml-string t)
  (add-hook 'mu4e-view-mode-hook 'muml-update)
  (add-hook 'mu4e-message-changed-hook 'muml-update)
  (add-hook 'mu4e-index-updated-hook 'muml-update)
  (muml-update))

(defun muml--disable-mode-line ()
  "Disable muml in the mode-line."
  (muml--remove-from-mode-line-string)
  (remove-hook 'mu4e-view-mode-hook 'muml-update)
  (remove-hook 'mu4e-message-changed-hook 'muml-update)
  (remove-hook 'mu4e-index-updated-hook 'muml-update))

;;;###autoload
(defun muml-update ()
  "Update count of mu query in the mode line."
  (interactive)
  (let ((result-count (muml--count-query-results (muml--query))))
    (setq muml-string
          (if (and (string= "0" result-count) muml-hide-mode-line-when-zero)
              ""
            (propertize
             (concat muml-prefix " " result-count)
             'help-echo "mu4e query results count"))))
  (force-mode-line-update))

(defun muml--query ()
  "Return the query that should be sent to mu, using either a bookmark, if provided, are the user specified query."
  (if muml-bookmark
      (muml--get-mu4e-bookmark-query-by-name muml-bookmark)
    muml-query))

(defun muml--get-mu4e-bookmark-query-by-name (bookmark)
  "Get the corresponding named mu4e bookmarked query for BOOKMARK, or return 'muml-query if none is found."
  (let ((chosen-bm
         (plist-get
          (lambda (bm)
            (string= bookmark (nth 1 bm)))
          mu4e-bookmarks)))
    (if chosen-bm
        (nth 0 chosen-bm)
      (progn
        (message (concat "[muml] Unable to find bookmark \"" bookmark "\"\n"
                         "[muml] Reverting to default query: " muml-query))
        muml-query))))

(defun muml--count-query-results (query)
  "Return the number of results in the mu database for QUERY."
  (number-to-string
   (length
    (seq-filter '(lambda (x)
                   (not (string-empty-p x)))
                (split-string
                 (s-trim (shell-command-to-string
                          (string-join (list mu4e-mu-binary
                                             "find"
                                             "--nocolor"
                                             (when mu4e-mu-home
                                               (concat "--muhome=" mu4e-mu-home))
                                             query
                                             "2> /dev/null")
                                       " ")))
                 "\n")))))

(defun muml--remove-from-mode-line-string ()
  "Remove the muml-string from the `global-mode-string'."
  (setq global-mode-string
        (delq 'muml-string global-mode-string)))

(provide 'muml)

;;; muml.el ends here
