-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                        Copyright (C) 2007-2009, AdaCore           --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Unchecked_Conversion;
with GNATCOLL.IO;               use GNATCOLL.IO;
with Glib.Values;               use Glib, Glib.Values;
with System;

package body GNATCOLL.VFS.GtkAda is

   Virtual_File_Type : Glib.GType := Glib.GType_None;
   --  Initialized only the first time this is needed, since we need glib
   --  initialized for this.
   --  ??? Could this be made a local variable

   function Virtual_File_Boxed_Copy
     (Boxed : System.Address) return System.Address;
   pragma Convention (C, Virtual_File_Boxed_Copy);
   procedure Virtual_File_Boxed_Free (Boxed : System.Address);
   pragma Convention (C, Virtual_File_Boxed_Free);
   --  Subprograms required for the support of GValue

   pragma Warnings (Off);
   --  This UC is safe aliasing-wise, so kill warning
   function To_Contents_Access is new Ada.Unchecked_Conversion
     (System.Address, GNATCOLL.IO.File_Access);
   pragma Warnings (On);

   --------------
   -- Set_File --
   --------------

   procedure Set_File
     (Value : in out Glib.Values.GValue; File : Virtual_File) is
   begin
      if File.Value = null then
         Set_Boxed (Value, System.Null_Address);
      else
         --  This results in a call to Virtual_File_Boxed_Copy, so increases
         --  the refcount of File.Value (which is expected since we now own
         --  one).
         Set_Boxed (Value, File.Value.all'Address);
      end if;
   end Set_File;

   --------------
   -- Get_File --
   --------------

   function Get_File (Value : Glib.Values.GValue) return Virtual_File is
      File : Virtual_File;
   begin
      File.Value := To_Contents_Access (Get_Boxed (Value));
      if File.Value /= null then
         File.Value.Ref_Count := File.Value.Ref_Count + 1;
      end if;

      return File;
   end Get_File;

   ---------------------------
   -- Get_Virtual_File_Type --
   ---------------------------

   function Get_Virtual_File_Type return Glib.GType is
   begin
      if Virtual_File_Type = Glib.GType_None then
         Virtual_File_Type := Glib.Boxed_Type_Register_Static
           ("Virtual_File", Virtual_File_Boxed_Copy'Access,
            Virtual_File_Boxed_Free'Access);
      end if;

      return Virtual_File_Type;
   end Get_Virtual_File_Type;

   -----------------------------
   -- Virtual_File_Boxed_Copy --
   -----------------------------

   function Virtual_File_Boxed_Copy
     (Boxed : System.Address) return System.Address
   is
      Value : constant File_Access := To_Contents_Access (Boxed);
   begin
      if Value /= null then
         Ref (Value);
      end if;

      return Boxed;
   end Virtual_File_Boxed_Copy;

   -----------------------------
   -- Virtual_File_Boxed_Free --
   -----------------------------

   procedure Virtual_File_Boxed_Free (Boxed : System.Address) is
      Value : File_Access := To_Contents_Access (Boxed);
   begin
      --  Release the reference we owned
      if Value /= null then
         Unref (Value);
      end if;
   end Virtual_File_Boxed_Free;

   --------------
   -- Set_File --
   --------------

   procedure Set_File
     (Tree_Store : access Gtk.Tree_Store.Gtk_Tree_Store_Record'Class;
      Iter       : Gtk.Tree_Model.Gtk_Tree_Iter;
      Column     : Glib.Gint;
      File       : Virtual_File)
   is
      Value : GValue;
   begin
      Init (Value, Get_Virtual_File_Type);
      Set_File (Value, File);
      Gtk.Tree_Store.Set_Value (Tree_Store, Iter, Column, Value);
      Unset (Value);
   end Set_File;

   --------------
   -- Get_File --
   --------------

   function Get_File
     (Tree_Model : access Gtk.Tree_Model.Gtk_Tree_Model_Record'Class;
      Iter       : Gtk.Tree_Model.Gtk_Tree_Iter;
      Column     : Glib.Gint) return Virtual_File
   is
      Value : GValue;
   begin
      Gtk.Tree_Model.Get_Value (Tree_Model, Iter, Column, Value);
      return Get_File (Value);
   end Get_File;

end GNATCOLL.VFS.GtkAda;
