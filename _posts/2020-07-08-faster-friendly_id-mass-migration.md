---
layout: post
title: How to make your friendly_id mass migration faster? Skip all the callbacks.
date: 2020-07-08
category: tech
---

I am currently working on integrating friendly_id gem into some of the models in [Talenox](https://www.talenox.com/?utm_source=anonozblog&utm_medium=blog&utm_campaign=friendly-id-post). Basically, it makes our in app URLs look nicer with human and company names in front, instead of just incremental primary key IDs. Oh boy... `Employee.all.each(&:save)` is fucking slow in production.

There are several things that can cause update and insert to slow down a lot for an ActiveRecord model:

1. Validations - especially when it involves multiple models
2. Callbacks - especially when they cause a chain of callbacks in other models
3. `belongs_to :parent, touch: true` - technically a callback to bust russian doll caches, but adding a slug does not necessitate busting caches

Guess what, we can skip all those. How? **By backfilling with an empty model class.**

Assuming we have an `Employee` model with a relation `employees`, this is how the migration file initially would look like:-

```ruby
# BAD
class BackfillEmployeesWithFriendlyId < ActiveRecord::Migration[5.0]
  def up
    print "Updating friendly_id slug for employees"
    Employee.where(slug: nil).each do |row|
      row.save; print('.')
    end
    puts ''
  end
end

```

What you can do is: Create an ActiveRecord model class in that migration class with none of the callbacks EXCEPT friendly_id and `slug_candidate` method.

```ruby
# GOOD
class BackfillEmployeesWithFriendlyId < ActiveRecord::Migration[5.0]

  # Using a blank class allows us to easily skip all callbacks that can make
  # mass migration slow.
  class FriendlyIdEmployee < ActiveRecord::Base
    self.table_name = 'employees'
    extend FriendlyId
    friendly_id :slug_candidate, use: [:slugged, :finders]

    def slug_candidate
      if first_name || last_name
        "#{first_name} #{last_name}"[0, 20]
      else
        "employee"
      end + " #{SecureRandom.hex[0, 8]}"
    end
  end

  def up
    print "Updating friendly_id slug for employees"
    FriendlyIdEmployee.where(slug: nil).each do |row|
      row.save; print('.')
    end
    puts ''
  end
end

```

However, I couldn't get the friendly_id history plug in to work properly yet. friendly_id history is implemented using ActiveRecord polymorphic. When the backfilling migration above is run, it will end up creating FriendlyId::Slug records with sluggable type of `BackfillEmployeesWithFriendlyId::FriendlyIdEmployee` instead of `Employee`. That also means you can't do subclassing of ActiveRecord models with friendly_id and expect history to work. Luckily we don't need it.
