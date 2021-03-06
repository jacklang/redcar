

class Redcar::EditTabPlugin
  def self.font_chooser_button(name)
    gtk_image = Gtk::Image.new(Gtk::Stock::SELECT_FONT,
                               Gtk::IconSize::MENU)
    gtk_hbox = Gtk::HBox.new
    gtk_label = Gtk::Label.new(Redcar::Preference.get(name))
    gtk_hbox.pack_start(gtk_image, false)
    gtk_hbox.pack_start(gtk_label)
    widget = Gtk::Button.new
    widget.add(gtk_hbox)
    class << widget
      attr_accessor :preference_value
    end
    widget.preference_value = Redcar::Preference.get(name)
    widget.signal_connect('clicked') do
      dialog = Gtk::FontSelectionDialog.new("Select Application Font")
      dialog.font_name = widget.preference_value
      dialog.preview_text = "So say we all!"
      if dialog.run == Gtk::Dialog::RESPONSE_OK
        puts font = dialog.font_name
        font = dialog.font_name
        widget.preference_value = font
        gtk_label.text = font
      end
      dialog.destroy
    end
    widget
  end
end
